import 'dart:async';

import 'lumi_api.dart';

typedef WorkspaceSnapshot = ({
  List<Note> notes,
  List<Folder> folders,
  List<LearningCanvas> canvases,
});

typedef OrderedNoteSave = ({Note note, bool isLatest});
typedef OrderedCanvasSave = ({LearningCanvas canvas, bool isLatest});

class WorkspaceWriteException implements Exception {
  const WorkspaceWriteException(this.isLatest);

  final bool isLatest;
}

/// Coordinates workspace API access and serializes writes for each entity.
class WorkspaceRepository {
  WorkspaceRepository({LumiApi? api}) : _api = api ?? LumiApi();

  final LumiApi _api;
  final Map<String, Future<void>> _noteSaveQueues = {};
  final Map<String, int> _noteSaveRevisions = {};
  final Map<String, Future<void>> _canvasSaveQueues = {};
  final Map<String, int> _canvasSaveRevisions = {};
  final Map<String, Note> _latestNotes = {};
  final Set<String> _deletedNoteIds = {};
  var _activeLoads = 0;
  var _loadGeneration = 0;

  Future<WorkspaceSnapshot> load() async {
    final generation = ++_loadGeneration;
    _activeLoads++;
    try {
      return await _loadSnapshot(generation);
    } finally {
      _activeLoads--;
      if (_activeLoads == 0) _deletedNoteIds.clear();
    }
  }

  Future<WorkspaceSnapshot> _loadSnapshot(int generation) async {
    final notesBeforeLoad = Map<String, Note>.from(_latestNotes);
    final (notes, folders, canvases) = await (
      _api.notes(),
      _api.folders(),
      _api.canvases(),
    ).wait;
    if (generation != _loadGeneration) {
      return (
        notes: List<Note>.unmodifiable(_latestNotes.values),
        folders: folders,
        canvases: canvases,
      );
    }
    final refreshedNotes = <String, Note>{};
    for (final note in notes) {
      if (_deletedNoteIds.contains(note.id)) continue;
      final before = notesBeforeLoad[note.id];
      final current = _latestNotes[note.id];
      if (before != null && !identical(before, current)) {
        if (current != null) refreshedNotes[note.id] = current;
      } else {
        refreshedNotes[note.id] = note;
      }
    }
    for (final entry in _latestNotes.entries) {
      if (!notesBeforeLoad.containsKey(entry.key) &&
          !refreshedNotes.containsKey(entry.key)) {
        refreshedNotes[entry.key] = entry.value;
      }
    }
    _latestNotes
      ..clear()
      ..addAll(refreshedNotes);
    final serverNoteIds = notes.map((note) => note.id).toSet();
    final mergedNotes = [
      for (final note in notes)
        if (refreshedNotes.containsKey(note.id)) refreshedNotes[note.id]!,
      for (final entry in refreshedNotes.entries)
        if (!serverNoteIds.contains(entry.key)) entry.value,
    ];
    return (notes: mergedNotes, folders: folders, canvases: canvases);
  }

  Future<Note> createNote({String? folderId}) async {
    final note = await _api.create(folderId: folderId);
    _deletedNoteIds.remove(note.id);
    _latestNotes[note.id] = note;
    return note;
  }

  Future<Folder> createFolder(String name, {String? parentId}) =>
      _api.createFolder(name, parentId: parentId);

  Future<void> deleteFolder(Folder folder) => _api.deleteFolder(folder);

  Future<Folder> renameFolder(Folder folder, String name) =>
      _api.updateFolder(folder, name);

  Future<void> deleteNote(Note note) async {
    final revision = (_noteSaveRevisions[note.id] ?? 0) + 1;
    _noteSaveRevisions[note.id] = revision;
    final previous = _noteSaveQueues[note.id] ?? Future<void>.value();
    final result = Completer<void>();
    final queued = previous.catchError((Object _) {}).then((_) async {
      try {
        await _api.delete(note);
        _latestNotes.remove(note.id);
        if (_activeLoads > 0) _deletedNoteIds.add(note.id);
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(
          WorkspaceWriteException(_noteSaveRevisions[note.id] == revision),
          stackTrace,
        );
      }
    });
    _noteSaveQueues[note.id] = queued;
    try {
      await result.future;
    } finally {
      if (identical(_noteSaveQueues[note.id], queued)) {
        _noteSaveQueues.remove(note.id);
        if (_noteSaveRevisions[note.id] == revision) {
          _noteSaveRevisions.remove(note.id);
        }
      }
    }
  }

  Future<Map<String, dynamic>> submitArtifactQuiz(
          String id, List<int> answers) =>
      _api.submitArtifactQuiz(id, answers);

  Future<List<AcademicArtifact>> artifacts() => _api.artifacts();

  Future<List<Note>> search(String query) => _api.search(query);

  Future<OrderedNoteSave> updateNote(Note note) =>
      _queueNoteWrite(note, (latest) {
        final moved = Note(
          id: latest.id,
          title: latest.title,
          content: latest.content,
          updatedAt: latest.updatedAt,
          createdAt: latest.createdAt,
          folderId: note.folderId,
        );
        return _api.update(moved, moved.title, moved.content);
      });

  Future<String> uploadImage(String base64Data, String contentType) =>
      _api.uploadAttachment(
        base64Data: base64Data,
        contentType: contentType,
      );

  Future<LearningCanvas> createCanvas({
    required String title,
    required List<String> noteIds,
  }) =>
      _api.createCanvas(title: title, noteIds: noteIds);

  Future<List<LearningCanvas>> canvases() => _api.canvases();

  Future<Map<String, dynamic>> submitCanvasQuiz({
    required String canvasId,
    required String quizId,
    required List<int> answers,
  }) =>
      _api.submitCanvasQuiz(
          canvasId: canvasId, quizId: quizId, answers: answers);

  Future<OrderedNoteSave> saveNote(
    Note original,
    String title,
    String content,
  ) =>
      _queueNoteWrite(
        original,
        (latest) => _api.update(latest, title, content),
      );

  Future<OrderedNoteSave> _queueNoteWrite(
    Note original,
    Future<Note> Function(Note latest) write,
  ) {
    final revision = (_noteSaveRevisions[original.id] ?? 0) + 1;
    _noteSaveRevisions[original.id] = revision;
    final previous = _noteSaveQueues[original.id] ?? Future<void>.value();
    final result = Completer<OrderedNoteSave>();
    final queued = previous.catchError((Object _) {}).then((_) async {
      try {
        final latest = _latestNotes[original.id] ?? original;
        final updated = await write(latest);
        _latestNotes[updated.id] = updated;
        result.complete((
          note: updated,
          isLatest: _noteSaveRevisions[original.id] == revision,
        ));
      } on Object catch (error, stackTrace) {
        result.completeError(
          WorkspaceWriteException(_noteSaveRevisions[original.id] == revision),
          stackTrace,
        );
      }
    });
    _noteSaveQueues[original.id] = queued;
    unawaited(queued.whenComplete(() {
      if (identical(_noteSaveQueues[original.id], queued)) {
        _noteSaveQueues.remove(original.id);
        if (_noteSaveRevisions[original.id] == revision) {
          _noteSaveRevisions.remove(original.id);
        }
      }
    }));
    return result.future;
  }

  Future<OrderedCanvasSave> saveCanvasLayout(
    LearningCanvas canvas,
    Map<String, CanvasPosition> positions,
  ) {
    final revision = (_canvasSaveRevisions[canvas.id] ?? 0) + 1;
    _canvasSaveRevisions[canvas.id] = revision;
    final previous = _canvasSaveQueues[canvas.id] ?? Future<void>.value();
    final result = Completer<OrderedCanvasSave>();
    final queued = previous.catchError((Object _) {}).then((_) async {
      try {
        final updated = await _api.updateCanvasLayout(canvas, positions);
        result.complete((
          canvas: updated,
          isLatest: _canvasSaveRevisions[canvas.id] == revision,
        ));
      } on Object catch (error, stackTrace) {
        result.completeError(
          WorkspaceWriteException(_canvasSaveRevisions[canvas.id] == revision),
          stackTrace,
        );
      }
    });
    _canvasSaveQueues[canvas.id] = queued;
    unawaited(queued.whenComplete(() {
      if (identical(_canvasSaveQueues[canvas.id], queued)) {
        _canvasSaveQueues.remove(canvas.id);
        if (_canvasSaveRevisions[canvas.id] == revision) {
          _canvasSaveRevisions.remove(canvas.id);
        }
      }
    }));
    return result.future;
  }

  void close() => _api.close();
}

# Shared Layouts

## App shell

`lib/ui/app.dart` composes the workspace shell and responsive view selection. It owns presentation selection state and calls into the data layer through `WorkspaceRepository`.

### `lib/ui/app.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../data/lumi_api.dart';
import '../data/workspace_repository.dart';
import 'coach_panel.dart';
import 'learning_views.dart';
import 'lumi_theme.dart';
import 'note_editor.dart';
import 'settings_page.dart';
import 'workspace_widgets.dart';

class LumiWebApp extends StatefulWidget {
  const LumiWebApp({super.key});

  @override
  State<LumiWebApp> createState() => _LumiWebAppState();
}

class _LumiWebAppState extends State<LumiWebApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lumi — Think. Connect. Learn.',
        debugShowCheckedModeBanner: false,
        theme: LumiTheme.light(),
        darkTheme: LumiTheme.dark(),
        themeMode: _themeMode,
        home: LumiWorkspace(
          isDark: _themeMode == ThemeMode.dark,
          onToggleTheme: () => setState(() {
            _themeMode = _themeMode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light;
          }),
        ),
      );
}

class LumiWorkspace extends StatefulWidget {
  const LumiWorkspace(
      {required this.onToggleTheme, required this.isDark, super.key});
  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<LumiWorkspace> createState() => _LumiWorkspaceState();
}

class _LumiWorkspaceState extends State<LumiWorkspace> {
  final _repository = WorkspaceRepository();
  List<Note> _notes = const [];
  List<Folder> _folders = const [];
  List<LearningCanvas> _canvases = const [];
  String? _selectedCanvasId;
  String? _selectedFolderId;
  List<Note> _searchResults = const [];
  Note? _selected;
  bool _loading = true;
  bool _agentOpen = false;
  bool _searchMode = false;
  String _workspaceView = 'notes';
  String? _error;
  String? _savedLabel;
  int _searchRevision = 0;
  int _loadRevision = 0;

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    try {
      final snapshot = await _repository.load();
      final notes = snapshot.notes;
      final folders = snapshot.folders;
      final canvases = snapshot.canvases;
      final selectedId = _selected?.id;
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _notes = notes;
        _folders = folders;
        _canvases = canvases;
        _selectedCanvasId = _selectedCanvasId == '__all__'
            ? '__all__'
            : canvases.any((canvas) => canvas.id == _selectedCanvasId)
                ? _selectedCanvasId
                : canvases.isEmpty
                    ? null
                    : canvases.first.id;
        _selected = notes.where((note) => note.id == selectedId).firstOrNull ??
            (notes.isEmpty ? null : notes.first);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loading = false;
        _error =
            'Can’t reach Lumi’s local service. Start the backend, then reload.';
      });
    }
  }

  Future<void> _createNote() async {
    try {
      final note = await _repository.createNote(
          folderId:
              _selectedFolderId == '__unfiled__' ? null : _selectedFolderId);
      if (!mounted) return;
      setState(() {
        _notes = [note, ..._notes];
        _selected = note;
        _searchMode = false;
      });
    } catch (_) {
      _showError(
          'Could not create the note. Check that the local service is running.');
    }
  }

  Future<void> _createFolder(Folder? parent) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parent == null ? 'New folder' : 'New subfolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Folder name',
            helperText: parent == null ? null : 'Inside ${parent.name}',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final folder = await _repository.createFolder(name, parentId: parent?.id);
      if (mounted) {
        setState(() {
          _folders = [..._folders, folder];
          _selectedFolderId = folder.id;
          _workspaceView = 'notes';
        });
      }
    } catch (_) {
      _showError('Could not create folder. Check the local service.');
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    try {
      await _repository.deleteFolder(folder);
      if (!mounted) return;
      if (_selectedFolderId == folder.id) _selectedFolderId = null;
      await _load();
    } catch (_) {
      _showError('Could not delete folder.');
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final updated = await _repository.renameFolder(folder, name);
      if (mounted) {
        setState(() {
          _folders = _folders
              .map((item) => item.id == updated.id ? updated : item)
              .toList();
        });
      }
    } catch (_) {
      _showError('Could not rename folder.');
    }
  }

  Future<void> _deleteSelected() async {
    final note = _selected;
    if (note == null) return;
    try {
      await _repository.deleteNote(note);
      if (!mounted) return;
      setState(() {
        _notes = _notes.where((item) => item.id != note.id).toList();
        _selected = _notes.isEmpty ? null : _notes.first;
      });
    } catch (_) {
      _showError('Could not delete this note.');
    }
  }

  Future<void> _search(String query) async {
    final revision = ++_searchRevision;
    if (query.trim().isEmpty) {
      setState(() {
        _searchMode = false;
        _searchResults = const [];
      });
      return;
    }
    try {
      final results = await _repository.search(query);
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _searchMode = true;
        _searchResults = results;
      });
    } catch (_) {
      if (!mounted || revision != _searchRevision) return;
      _showError(
          'Search is unavailable while the local service is disconnected.');
    }
  }

  Future<bool> _save(Note original, String title, String content) async {
    try {
      final result = await _repository.saveNote(original, title, content);
      if (mounted && result.isLatest) {
        setState(() {
          _notes = [
            result.note,
            ..._notes.where((item) => item.id != result.note.id),
          ];
          if (_selected?.id == result.note.id) _selected = result.note;
          _savedLabel = 'Saved locally';
        });
      }
      return true;
    } on WorkspaceWriteException catch (error) {
      if (mounted && error.isLatest) {
        setState(() => _savedLabel = 'Save failed');
      }
      return false;
    } catch (_) {
      if (mounted) setState(() => _savedLabel = 'Save failed');
      return false;
    }
  }

  Future<String> _uploadImage(String data, String contentType) =>
      _repository.uploadImage(data, contentType);

  Future<void> _saveCanvasLayout(
    LearningCanvas canvas,
    Map<String, CanvasPosition> positions,
  ) async {
    try {
      final result = await _repository.saveCanvasLayout(canvas, positions);
      if (!mounted || !result.isLatest) return;
      setState(() {
        _canvases = _canvases
            .map((item) => item.id == result.canvas.id ? result.canvas : item)
            .toList();
        _savedLabel = 'Canvas saved';
      });
    } on WorkspaceWriteException catch (error) {
      if (mounted && error.isLatest) {
        try {
          final latest = await _repository.canvases();
          if (!mounted) return;
          setState(() => _canvases = latest);
        } catch (_) {
          // Keep the current board visible if the canonical refresh also fails.
        }
        _showError('Could not save the canvas layout.');
      }
    } catch (_) {
      if (mounted) _showError('Could not save the canvas layout.');
    }
  }

  Future<void> _createCanvas() async {
    final controller = TextEditingController();
    final selectedIds = _notes.take(30).map((note) => note.id).toSet();
    final result = await showDialog<({String title, List<String> noteIds})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('New canvas'),
          content: SizedBox(
            width: 440,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Canvas name'),
                  onChanged: (_) => updateDialog(() {}),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose notes (${selectedIds.length}/30)'),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _notes.isEmpty
                      ? const Center(child: Text('Create a note first.'))
                      : ListView.builder(
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final selected = selectedIds.contains(note.id);
                            return CheckboxListTile(
                              dense: true,
                              value: selected,
                              title: Text(note.title),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: selected || selectedIds.length < 30
                                  ? (value) => updateDialog(() {
                                        if (value == true) {
                                          selectedIds.add(note.id);
                                        } else {
                                          selectedIds.remove(note.id);
                                        }
                                      })
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedIds.isEmpty || controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext,
                      (title: controller.text.trim(), noteIds: selectedIds.toList())),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      final canvas = await _repository.createCanvas(
        title: result.title,
        noteIds: result.noteIds,
      );
      if (!mounted) return;
      setState(() {
        _canvases = [canvas, ..._canvases];
        _selectedCanvasId = canvas.id;
        _workspaceView = 'canvas';
      });
    } catch (_) {
      _showError('Could not create canvas. Check the local service.');
    }
  }

  Future<void> _moveNote(Note note, String? folderId) async {
    final moved = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      updatedAt: note.updatedAt,
      folderId: folderId,
    );
    try {
      final result = await _repository.updateNote(moved);
      if (!result.isLatest) return;
      final updated = result.note;
      if (!mounted) return;
      setState(() {
        _notes = _notes
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        if (_selected?.id == updated.id) _selected = updated;
      });
    } on WorkspaceWriteException catch (error) {
      if (error.isLatest) _showError('Could not move this note.');
    } catch (_) {
      _showError('Could not move this note.');
    }
  }

  Future<void> _addNoteLink(Note source, Note target) async {
    if (target.title.contains('[') || target.title.contains(']') ||
        _notes.where((note) => note.title.toLowerCase() == target.title.toLowerCase()).length != 1) {
      _showError('This note title cannot be linked unambiguously. Rename it first.');
      return;
    }
    if (RegExp(r'\[\[' + RegExp.escape(target.title) + r'\]\]',
            caseSensitive: false)
        .hasMatch(source.content)) {
      _showError('That connection already exists.');
      return;
    }
    final separator = source.content.isEmpty || source.content.endsWith('\n')
        ? ''
        : '\n';
    await _save(source, source.title,
        '${source.content}$separator\n[[${target.title}]]');
  }

  Future<void> _removeNoteLink(Note source, Note target) async {
    final escaped = RegExp.escape(target.title);
    final content = source.content
        .replaceAll(RegExp(r'\[\[' + escaped + r'\]\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trimRight();
    await _save(source, source.title, content);
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= 760;
    final showAgentBeside = width >= 1180 && _agentOpen;
    final showAgentOverlay = width < 1180 && _agentOpen;
    final visibleNotes = _selectedFolderId == null
        ? _notes
        : _selectedFolderId == '__unfiled__'
            ? _notes.where((note) => note.folderId == null).toList()
            : _notes.where((note) => _belongsToFolderTree(
                note.folderId, _selectedFolderId!, _folders)).toList();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                if (showSidebar)
                  WorkspaceSidebar(
                    notes: visibleNotes,
                    folders: _folders,
                    selectedFolderId: _selectedFolderId,
                    onSelectFolder: (id) => setState(() {
                      _selectedFolderId = id;
                      _workspaceView = 'notes';
                    }),
                    onCreateFolder: _createFolder,
                    onDeleteFolder: _deleteFolder,
                    onRenameFolder: _renameFolder,
                    selected: _selected,
                    searchMode: _searchMode,
                    onCreate: _createNote,
                    onSelect: (note) => setState(() {
                      _selected = note;
                      _searchMode = false;
                      _workspaceView = 'notes';
                    }),
                    onSearch: _search,
                    onToggleTheme: widget.onToggleTheme,
                    onSettings: () => setState(() {
                      _workspaceView = 'settings';
                      _searchMode = false;
                      _agentOpen = false;
                    }),
                    workspaceView: _workspaceView,
                    onWorkspaceView: (view) => setState(() {
                      _workspaceView = view;
                      _searchMode = false;
                    }),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      WorkspaceTopBar(
                        note: _selected,
                        savedLabel: _savedLabel,
                        agentOpen: _agentOpen,
                        onToggleAgent: () =>
                            setState(() => _agentOpen = !_agentOpen),
                        onDelete: _deleteSelected,
                        onCreate: _createNote,
                        onSearch: _search,
                        onSettings: () => setState(() {
                          _workspaceView = 'settings';
                          _searchMode = false;
                          _agentOpen = false;
                        }),
                      ),
                      if (_error != null)
                        ServiceBanner(message: _error!, onRetry: _load),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _searchMode
                                ? SearchResults(
                                    notes: _searchResults,
                                    onSelect: (note) => setState(() {
                                      _selected = note;
                                      _searchMode = false;
                                      _workspaceView = 'notes';
                                    }),
                                  )
                                : _workspaceView == 'settings'
                                    ? SettingsPage(
                                        isDark: widget.isDark,
                                        onToggleTheme: widget.onToggleTheme,
                                      )
                                    : _workspaceView == 'canvas'
                                        ? CanvasView(
                                            notes: _notes,
                                            canvases: _canvases,
                                            selectedCanvasId: _selectedCanvasId,
                                            onCanvasChanged: (id) => setState(
                                                () => _selectedCanvasId = id),
                                            onPositionsChanged: _saveCanvasLayout,
                                            onCreateCanvas: _createCanvas,
                                            onSelect: (note) => setState(() {
                                              _selected = note;
                                              _workspaceView = 'notes';
                                            }),
                                          )
                                        : _workspaceView == 'graph'
                                            ? KnowledgeGraph(
                                                notes: _notes,
                                                onSelect: (note) => setState(() {
                                                  _selected = note;
                                                  _workspaceView = 'notes';
                                                }),
                                                onAddLink: _addNoteLink,
                                                onRemoveLink: _removeNoteLink,
                                              )
                                            : _selected == null
                                                ? WorkspaceWelcome(
                                                    onCreate: _createNote)
                                                : NoteEditor(
                                                    key:
                                                        ValueKey(_selected!.id),
                                                    note: _selected!,
                                                    folders: _folders,
                                                    onSave: _save,
                                                    onMove: _moveNote,
                                                    onUploadImage: _uploadImage,
                                                  ),
                      ),
                    ],
                  ),
                ),
                if (showAgentBeside)
                  CoachPanel(
                      note: _selected,
                      onWorkspaceChanged: _load,
                      onClose: () => setState(() => _agentOpen = false)),
              ],
            ),
            if (showAgentOverlay)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: width < 760 ? width : 340,
                child: CoachPanel(
                  note: _selected,
                  onWorkspaceChanged: _load,
                  onClose: () => setState(() => _agentOpen = false),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: !showSidebar && !showAgentOverlay
          ? FloatingActionButton(
              onPressed: () => setState(() => _agentOpen = true),
              tooltip: 'Open Lumi Coach',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
    );
  }
}

bool _belongsToFolderTree(
  String? candidateId,
  String ancestorId,
  List<Folder> folders,
) {
  if (candidateId == null) return false;
  final byId = {for (final folder in folders) folder.id: folder};
  final visited = <String>{};
  var currentId = candidateId;
  while (visited.add(currentId)) {
    if (currentId == ancestorId) return true;
    final parentId = byId[currentId]?.parentId;
    if (parentId == null) return false;
    currentId = parentId;
  }
  return false;
}
```

## Workspace navigation and top bar

`lib/ui/workspace_widgets.dart` contains the sidebar, folder tree, note rows, navigation rows, and workspace top bar.

### `lib/ui/workspace_widgets.dart`

```dart
import 'package:flutter/material.dart';

import '../data/lumi_api.dart';
import 'lumi_theme.dart';

class _FolderTree extends StatefulWidget {
  const _FolderTree({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
  });

  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<Folder?> onCreateFolder;
  final ValueChanged<Folder> onRenameFolder;
  final ValueChanged<Folder> onDeleteFolder;

  @override
  State<_FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends State<_FolderTree> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final byId = {for (final folder in widget.folders) folder.id: folder};
    final children = <String?, List<Folder>>{};
    for (final folder in widget.folders) {
      final parentId = byId.containsKey(folder.parentId) ? folder.parentId : null;
      children.putIfAbsent(parentId, () => []).add(folder);
    }
    for (final siblings in children.values) {
      siblings.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final rows = <Widget>[
      ListTile(
        dense: true,
        leading: const Icon(Icons.folder_open_outlined),
        title: const Text('Unfiled'),
        selected: widget.selectedFolderId == '__unfiled__',
        onTap: () => widget.onSelectFolder('__unfiled__'),
      ),
    ];
    final visited = <String>{};
    void addChildren(String? parentId, int depth) {
      for (final folder in children[parentId] ?? const <Folder>[]) {
        if (!visited.add(folder.id)) continue;
        final nested = children[folder.id] ?? const <Folder>[];
        rows.add(_FolderTreeRow(
          folder: folder,
          depth: depth,
          selected: widget.selectedFolderId == folder.id,
          expanded: !_collapsed.contains(folder.id),
          hasChildren: nested.isNotEmpty,
          onSelect: () => widget.onSelectFolder(folder.id),
          onToggle: nested.isEmpty
              ? null
              : () => setState(() {
                    if (!_collapsed.add(folder.id)) _collapsed.remove(folder.id);
                  }),
          onCreateChild: () => widget.onCreateFolder(folder),
          onRename: () => widget.onRenameFolder(folder),
          onDelete: () => widget.onDeleteFolder(folder),
        ));
        if (!_collapsed.contains(folder.id)) addChildren(folder.id, depth + 1);
      }
    }

    addChildren(null, 0);
    for (final folder in widget.folders) {
      if (visited.add(folder.id)) {
        rows.add(_FolderTreeRow(
          folder: folder,
          depth: 0,
          selected: widget.selectedFolderId == folder.id,
          expanded: true,
          hasChildren: false,
          onSelect: () => widget.onSelectFolder(folder.id),
          onToggle: null,
          onCreateChild: () => widget.onCreateFolder(folder),
          onRename: () => widget.onRenameFolder(folder),
          onDelete: () => widget.onDeleteFolder(folder),
        ));
      }
    }
    return ListView(padding: EdgeInsets.zero, children: rows);
  }
}

class _FolderTreeRow extends StatelessWidget {
  const _FolderTreeRow({
    required this.folder,
    required this.depth,
    required this.selected,
    required this.expanded,
    required this.hasChildren,
    required this.onSelect,
    required this.onToggle,
    required this.onCreateChild,
    required this.onRename,
    required this.onDelete,
  });

  final Folder folder;
  final int depth;
  final bool selected;
  final bool expanded;
  final bool hasChildren;
  final VoidCallback onSelect;
  final VoidCallback? onToggle;
  final VoidCallback onCreateChild;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: 8 + depth * 16, right: 4),
        horizontalTitleGap: 8,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 20,
            child: hasChildren
                ? IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: expanded ? 'Collapse folder' : 'Expand folder',
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    ),
                  )
                : null,
          ),
          Icon(selected ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 18),
        ]),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onTap: onSelect,
        trailing: PopupMenuButton<String>(
          tooltip: 'Folder actions',
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (action) {
            switch (action) {
              case 'create':
                onCreateChild();
              case 'rename':
                onRename();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'create', child: Text('New subfolder')),
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      );
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    required this.notes,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onDeleteFolder,
    required this.onRenameFolder,
    required this.selected,
    required this.searchMode,
    required this.onCreate,
    required this.onSelect,
    required this.onSearch,
    required this.onToggleTheme,
    required this.onSettings,
    required this.workspaceView,
    required this.onWorkspaceView,
    super.key,
  });

  final List<Note> notes;
  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<Folder?> onCreateFolder;
  final ValueChanged<Folder> onDeleteFolder;
  final ValueChanged<Folder> onRenameFolder;
  final Note? selected;
  final bool searchMode;
  final VoidCallback onCreate;
  final ValueChanged<Note> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleTheme;
  final VoidCallback onSettings;
  final String workspaceView;
  final ValueChanged<String> onWorkspaceView;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: Theme.of(context).extension<LumiTokens>()!.surface,
        border:
            Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
            child: Row(children: [
              Text('Lumi',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('Think. Connect. Learn.',
                  style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New note'),
              style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search your notes',
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Text('WORKSPACE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1, color: colors.onSurfaceVariant)),
          ),
          _NavRow(
              icon: Icons.description_outlined,
              label: 'All notes',
              selected: !searchMode && workspaceView == 'notes',
              onTap: () {
                onSelectFolder(null);
                onWorkspaceView('notes');
              }),
          ListTile(
            dense: true,
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Canvas'),
            selected: workspaceView == 'canvas',
            onTap: () => onWorkspaceView('canvas'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Knowledge graph'),
            selected: workspaceView == 'graph',
            onTap: () => onWorkspaceView('graph'),
          ),
          if (searchMode)
            const _NavRow(
                icon: Icons.search, label: 'Search results', selected: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 4),
            child: Row(children: [
              Expanded(
                  child: Text('FOLDERS',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(letterSpacing: 1))),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Create folder',
                onPressed: () => onCreateFolder(null),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              ),
            ]),
          ),
          SizedBox(
            height: ((folders.length + 1) * 48).clamp(48, 240).toDouble(),
            child: _FolderTree(
              folders: folders,
              selectedFolderId: selectedFolderId,
              onSelectFolder: onSelectFolder,
              onCreateFolder: onCreateFolder,
              onRenameFolder: onRenameFolder,
              onDeleteFolder: onDeleteFolder,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Row(children: [
              Expanded(
                  child: Text('RECENT NOTES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1, color: colors.onSurfaceVariant))),
              Text('${notes.length}',
                  style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
          Expanded(
            child: notes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                    child: Text('Your notes will appear here.',
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _NoteTile(
                          note: note,
                          selected: selected?.id == note.id,
                          onTap: () => onSelect(note));
                    },
                  ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Settings'),
            selected: workspaceView == 'settings',
            trailing: IconButton(
              tooltip: 'Open settings',
              onPressed: onSettings,
              icon: const Icon(Icons.chevron_right),
            ),
            onTap: onSettings,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Text('Private workspace · Stored on this computer',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow(
      {required this.icon,
      required this.label,
      required this.selected,
      this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            dense: true,
            leading: Icon(icon, size: 19),
            title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            minLeadingWidth: 24,
            visualDensity: VisualDensity.compact,
            onTap: onTap,
          ),
        ),
      );
}

class _NoteTile extends StatelessWidget {
  const _NoteTile(
      {required this.note, required this.selected, required this.onTap});
  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            dense: true,
            onTap: onTap,
            leading: const Icon(Icons.article_outlined, size: 18),
            title:
                Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(note.content.isEmpty ? 'Empty note' : note.content,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            minLeadingWidth: 22,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
}

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar(
      {required this.note,
      required this.savedLabel,
      required this.agentOpen,
      required this.onToggleAgent,
      required this.onDelete,
      required this.onCreate,
      required this.onSearch,
      required this.onSettings,
      super.key});
  final Note? note;
  final String? savedLabel;
  final bool agentOpen;
  final VoidCallback onToggleAgent;
  final VoidCallback onDelete;
  final VoidCallback onCreate;
  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(children: [
          const Icon(Icons.home_outlined, size: 18),
          const SizedBox(width: 8),
          Text('Workspace', style: Theme.of(context).textTheme.bodySmall),
          const Icon(Icons.chevron_right, size: 18),
          Expanded(
              child: Text(note?.title ?? 'Learning workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall)),
          if (savedLabel != null)
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(savedLabel!,
                    style: Theme.of(context).textTheme.labelSmall)),
          IconButton(
              tooltip: 'Search notes',
              onPressed: () => _showSearch(context),
              icon: const Icon(Icons.search)),
          IconButton(
              tooltip: 'New note',
              onPressed: onCreate,
              icon: const Icon(Icons.add)),
          if (note != null)
            IconButton(
                tooltip: 'Delete note',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline)),
          IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined)),
          IconButton(
            tooltip: agentOpen ? 'Close Lumi Coach' : 'Open Lumi Coach',
            onPressed: onToggleAgent,
            icon: Icon(Icons.auto_awesome,
                color: Theme.of(context).extension<LumiTokens>()!.aiAccent),
          ),
        ]),
      );

  Future<void> _showSearch(BuildContext context) async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search your notes'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Search titles and content'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Search')),
        ],
      ),
    );
    controller.dispose();
    if (query != null) onSearch(query);
  }
}
```

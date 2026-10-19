import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import '../data/workspace_repository.dart';
import 'appearance_storage.dart';
import 'artifacts_page.dart';
import 'coach_panel.dart';
import 'learning_views.dart';
import 'lumi_theme.dart';
import 'note_editor.dart';
import 'settings_page.dart';
import 'settings_controller.dart';
import 'workspace_widgets.dart';

class LumiWebApp extends StatefulWidget {
  const LumiWebApp({super.key});

  @override
  State<LumiWebApp> createState() => _LumiWebAppState();
}

class _LumiWebAppState extends State<LumiWebApp> {
  static const _themeModeKey = 'lumi.theme.mode';
  static const _webAccentIndexKey = 'lumi.web.accent-cycle-index';

  final _settings = SettingsController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late ThemeMode _themeMode;
  late LumiAccent _accent;

  @override
  void initState() {
    super.initState();
    _themeMode = readAppearanceValue(_themeModeKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _accent = kIsWeb ? _nextWebAccent() : LumiAccent.sage;
    _settings.load();
  }

  LumiAccent _nextWebAccent() {
    final storedNext =
        int.tryParse(readAppearanceValue(_webAccentIndexKey) ?? '0');
    final index = (storedNext ?? 0) % LumiAccent.values.length;
    writeAppearanceValue(
      _webAccentIndexKey,
      ((index + 1) % LumiAccent.values.length).toString(),
    );
    return LumiAccent.values[index];
  }

  void _toggleTheme() {
    final mode = _settings.settings.text('theme');
    final dark = mode == 'dark' ||
        mode == 'system' &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
    _settings.save({'theme': dark ? 'light' : 'dark'}).catchError((Object _) {
      _messengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text(
              'Could not save the theme. Check the local service and try again.')));
    });
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSettingsScope(
        controller: _settings,
        child: ListenableBuilder(
            listenable: _settings,
            builder: (context, _) {
              final preferences = _settings.settings;
              final mode = _settings.loaded
                  ? preferences.text('theme')
                  : (_themeMode == ThemeMode.dark ? 'dark' : 'light');
              final selectedAccent = preferences.flag('rotateAccent')
                  ? _accent
                  : LumiAccent.values.byName(preferences.text('accent'));
              final size = switch (preferences.text('textSize')) {
                'small' => .9,
                'large' => 1.15,
                _ => 1.0
              };
              ThemeData themed(ThemeData theme) => theme.copyWith(
                    visualDensity: preferences.text('density') == 'compact'
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    pageTransitionsTheme: preferences.flag('reduceMotion')
                        ? const PageTransitionsTheme(builders: {
                            TargetPlatform.android: _NoPageTransition(),
                            TargetPlatform.linux: _NoPageTransition(),
                            TargetPlatform.windows: _NoPageTransition(),
                            TargetPlatform.macOS: _NoPageTransition(),
                            TargetPlatform.iOS: _NoPageTransition(),
                            TargetPlatform.fuchsia: _NoPageTransition(),
                          })
                        : theme.pageTransitionsTheme,
                  );
              return MaterialApp(
                title: 'Lumi — Think. Connect. Learn.',
                scaffoldMessengerKey: _messengerKey,
                debugShowCheckedModeBanner: false,
                theme: themed(LumiTheme.light(accent: selectedAccent)),
                darkTheme: themed(LumiTheme.dark(accent: selectedAccent)),
                themeMode: switch (mode) {
                  'dark' => ThemeMode.dark,
                  'system' => ThemeMode.system,
                  _ => ThemeMode.light
                },
                themeAnimationDuration: preferences.flag('reduceMotion')
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                            MediaQuery.textScalerOf(context).scale(1) * size),
                        disableAnimations: preferences.flag('reduceMotion')),
                    child: child!),
                home: Builder(
                    builder: (context) => LumiWorkspace(
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                          accent: selectedAccent,
                          onToggleTheme: _toggleTheme,
                        )),
              );
            }),
      );
}

class LumiWorkspace extends StatefulWidget {
  const LumiWorkspace(
      {required this.onToggleTheme,
      required this.isDark,
      required this.accent,
      super.key});
  final VoidCallback onToggleTheme;
  final bool isDark;
  final LumiAccent accent;

  @override
  State<LumiWorkspace> createState() => _LumiWorkspaceState();
}

class _LumiWorkspaceState extends State<LumiWorkspace> {
  final _repository = WorkspaceRepository();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Note> _notes = const [];
  List<Folder> _folders = const [];
  List<LearningCanvas> _canvases = const [];
  String? _selectedCanvasId;
  String? _selectedFolderId;
  List<Note> _searchResults = const [];
  Note? _selected;
  bool _loading = true;
  bool _appliedStartPage = false;
  bool _agentOpen = false;
  bool _searchMode = false;
  String _workspaceView = 'artifacts';
  String? _error;
  String? _savedLabel;
  int _searchRevision = 0;
  int _loadRevision = 0;
  int _chatOpenRevision = 0;
  int _settingsInitialSection = 0;
  List<({String agentPath, String sessionId, String title})> _recentChats = [];
  static const _recentChatsKey = 'lumi.chat.recent';

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _workspaceView = _settingsStartPage();
    _readRecentChats();
    _load();
  }

  String _settingsStartPage() {
    try {
      final raw = readAppearanceValue('lumi.application-settings');
      if (raw != null) {
        return (jsonDecode(raw) as Map<String, dynamic>)['startPage']
                as String? ??
            'artifacts';
      }
    } on Object {/* Use the default library. */}
    return 'artifacts';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppSettingsScope.maybeOf(context);
    if (!_appliedStartPage && controller != null && controller.loaded) {
      if (_workspaceView == 'artifacts') {
        _workspaceView = controller.settings.text('startPage');
      }
      _appliedStartPage = true;
    }
  }

  void _readRecentChats() {
    try {
      final raw = readAppearanceValue(_recentChatsKey);
      if (raw == null) return;
      final items = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((item) => (
                agentPath: item['agentPath'] as String? ?? '/api/assistant',
                sessionId: item['sessionId'] as String? ?? '',
                title: item['title'] as String? ?? 'Conversation',
              ))
          .where((item) => item.sessionId.isNotEmpty)
          .toList();
      _recentChats = items;
    } on Object {
      _recentChats = [];
    }
  }

  void _saveRecentChat(String agentPath, String sessionId, String title) {
    final chats = [
      (agentPath: agentPath, sessionId: sessionId, title: title),
      ..._recentChats.where((chat) => chat.sessionId != sessionId),
    ].take(AppSettingsScope.settingsOf(context).number('recentLimit')).toList();
    setState(() => _recentChats = chats);
    writeAppearanceValue(
        _recentChatsKey,
        jsonEncode(chats
            .map((chat) => {
                  'agentPath': chat.agentPath,
                  'sessionId': chat.sessionId,
                  'title': chat.title,
                })
            .toList()));
  }

  void _removeRecentChat(String sessionId) {
    final chats =
        _recentChats.where((chat) => chat.sessionId != sessionId).toList();
    setState(() => _recentChats = chats);
    writeAppearanceValue(
        _recentChatsKey,
        jsonEncode(chats
            .map((chat) => {
                  'agentPath': chat.agentPath,
                  'sessionId': chat.sessionId,
                  'title': chat.title,
                })
            .toList()));
  }

  void _openRecentChat(({String agentPath, String sessionId}) chat) {
    writeAppearanceValue('lumi.chat.active-agent', chat.agentPath);
    writeAppearanceValue('lumi.chat.session.${chat.agentPath}', chat.sessionId);
    setState(() {
      _agentOpen = true;
      _chatOpenRevision++;
    });
    if (MediaQuery.sizeOf(context).width < 1280) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _load({bool selectLatestCanvas = false}) async {
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
        _selectedCanvasId = selectLatestCanvas && canvases.isNotEmpty
            ? canvases.first.id
            : _selectedCanvasId == '__all__'
                ? '__all__'
                : canvases.any((canvas) => canvas.id == _selectedCanvasId)
                    ? _selectedCanvasId
                    : canvases.isEmpty
                        ? null
                        : canvases.first.id;
        if (selectLatestCanvas && canvases.isNotEmpty) {
          _workspaceView = 'canvas';
          _searchMode = false;
        }
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

  Future<void> _retryLoad() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
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
        _workspaceView = 'notes';
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

  Future<Map<String, dynamic>> _submitCanvasQuiz(
    String canvasId,
    String quizId,
    List<int> answers,
  ) =>
      _repository.submitCanvasQuiz(
          canvasId: canvasId, quizId: quizId, answers: answers);

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
                  : () => Navigator.pop(dialogContext, (
                        title: controller.text.trim(),
                        noteIds: selectedIds.toList()
                      )),
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
      createdAt: note.createdAt,
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
    if (target.title.contains('[') ||
        target.title.contains(']') ||
        _notes
                .where((note) =>
                    note.title.toLowerCase() == target.title.toLowerCase())
                .length !=
            1) {
      _showError(
          'This note title cannot be linked unambiguously. Rename it first.');
      return;
    }
    if (RegExp(r'\[\[' + RegExp.escape(target.title) + r'\]\]',
            caseSensitive: false)
        .hasMatch(source.content)) {
      _showError('That connection already exists.');
      return;
    }
    final separator =
        source.content.isEmpty || source.content.endsWith('\n') ? '' : '\n';
    await _save(source, source.title,
        '${source.content}$separator\n[[${target.title}]]');
  }

  Future<void> _removeNoteLink(Note source, Note target) async {
    final escaped = RegExp.escape(target.title);
    final content = source.content
        .replaceAll(
            RegExp(r'\[\[' + escaped + r'\]\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trimRight();
    await _save(source, source.title, content);
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openAiSettings() => setState(() {
        _workspaceView = 'settings';
        _settingsInitialSection = 2;
        _searchMode = false;
        _agentOpen = false;
      });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= 1280;
    final showRail = width >= 768 && width < 1280;
    final showAgentBeside = width >= 1280 && _agentOpen;
    final showAgentOverlay = width < 1280 && _agentOpen;
    final scaffoldKey = _scaffoldKey;
    void closeCompactDrawer() {
      if (width < 1280) scaffoldKey.currentState?.closeDrawer();
    }

    Widget sidebar() => WorkspaceSidebar(
          notes: _notes,
          canvases: _canvases,
          selectedCanvasId:
              _workspaceView == 'canvas' ? _selectedCanvasId : null,
          onSelectCanvas: (canvas) => setState(() {
            _selectedCanvasId = canvas.id;
            _workspaceView = 'canvas';
            _searchMode = false;
            closeCompactDrawer();
          }),
          folders: _folders,
          selectedFolderId: _selectedFolderId,
          onSelectFolder: (id) => setState(() {
            _selectedFolderId = id;
            _searchMode = false;
            _selected = _notes
                .where((note) => id == '__unfiled__'
                    ? note.folderId == null ||
                        !_folders.any((folder) => folder.id == note.folderId)
                    : id == null ||
                        _belongsToFolderTree(note.folderId, id, _folders))
                .firstOrNull;
            _workspaceView = 'notes';
            closeCompactDrawer();
          }),
          onCreateFolder: _createFolder,
          onDeleteFolder: _deleteFolder,
          onRenameFolder: _renameFolder,
          selected:
              _workspaceView == 'notes' && !_searchMode ? _selected : null,
          searchMode: _searchMode,
          onCreate: _createNote,
          onSelect: (note) => setState(() {
            _selectedFolderId = note.folderId;
            _selected = note;
            _searchMode = false;
            _workspaceView = 'notes';
            closeCompactDrawer();
          }),
          onSearch: _search,
          onToggleTheme: widget.onToggleTheme,
          onSettings: () => setState(() {
            _workspaceView = 'settings';
            _settingsInitialSection = 0;
            _searchMode = false;
            _agentOpen = false;
            closeCompactDrawer();
          }),
          workspaceView: _workspaceView,
          onWorkspaceView: (view) => setState(() {
            _workspaceView = view;
            _searchMode = false;
            closeCompactDrawer();
          }),
          recentChats: _recentChats,
          onSelectAgent: (path) {
            writeAppearanceValue('lumi.chat.active-agent', path);
            setState(() {
              _agentOpen = true;
              _chatOpenRevision++;
            });
            closeCompactDrawer();
          },
          onOpenChat: _openRecentChat,
        );
    return Scaffold(
      key: scaffoldKey,
      drawer: width < 1280 ? Drawer(child: SafeArea(child: sidebar())) : null,
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                if (showSidebar) sidebar(),
                if (showRail)
                  _WorkspaceRail(
                    view: _workspaceView,
                    onMenu: () => scaffoldKey.currentState?.openDrawer(),
                    onSelect: (view) => setState(() {
                      _workspaceView = view;
                      _searchMode = false;
                    }),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      WorkspaceTopBar(
                        note: _workspaceView == 'notes' ? _selected : null,
                        viewTitle: _searchMode
                            ? 'Search'
                            : switch (_workspaceView) {
                                'home' => 'Home',
                                'artifacts' => 'Artifacts',
                                'canvas' => 'Canvas',
                                'graph' => 'Knowledge graph',
                                'settings' => 'Settings',
                                _ => null,
                              },
                        savedLabel: _savedLabel,
                        agentOpen: _agentOpen,
                        onToggleAgent: () =>
                            setState(() => _agentOpen = !_agentOpen),
                        onDelete: _deleteSelected,
                        onCreate: _createNote,
                        onSearch: _search,
                        onSettings: () => setState(() {
                          _workspaceView = 'settings';
                          _settingsInitialSection = 0;
                          _searchMode = false;
                          _agentOpen = false;
                        }),
                        onMenu: width < 768
                            ? () => scaffoldKey.currentState?.openDrawer()
                            : null,
                      ),
                      if (_error != null)
                        ServiceBanner(message: _error!, onRetry: _retryLoad),
                      Expanded(
                        child: !_searchMode && _workspaceView == 'home'
                            ? WorkspaceWelcome(
                                onCreate: _createNote,
                                hasNotes: _notes.isNotEmpty,
                                onOpenArtifacts: () => setState(
                                    () => _workspaceView = 'artifacts'),
                                onOpenCanvas: () =>
                                    setState(() => _workspaceView = 'canvas'),
                                onOpenCoach: () =>
                                    setState(() => _agentOpen = true),
                              )
                            : _loading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _searchMode
                                    ? SearchResults(
                                        notes: _searchResults,
                                        onSelect: (note) => setState(() {
                                          _selected = note;
                                          _searchMode = false;
                                          _workspaceView = 'notes';
                                        }),
                                      )
                                    : _workspaceView == 'artifacts'
                                        ? ArtifactsPage(
                                            load: _repository.artifacts,
                                            submitQuiz:
                                                _repository.submitArtifactQuiz,
                                            revision: _loadRevision,
                                            onCreate: _createNote,
                                            onCoach: () => setState(
                                                () => _agentOpen = true),
                                            hasSource: (artifact) =>
                                                (artifact.kind == 'Notes' &&
                                                    _notes.any((n) =>
                                                        n.id ==
                                                        artifact.sourceId)) ||
                                                (artifact.kind == 'Canvases' &&
                                                    _canvases.any((c) =>
                                                        c.id ==
                                                        artifact.sourceId)),
                                            onOpenSource: (artifact) =>
                                                setState(() {
                                              if (artifact.kind == 'Notes') {
                                                _selected = _notes
                                                    .where((n) =>
                                                        n.id ==
                                                        artifact.sourceId)
                                                    .firstOrNull;
                                                _workspaceView = 'notes';
                                              } else {
                                                _selectedCanvasId =
                                                    artifact.sourceId;
                                                _workspaceView = 'canvas';
                                              }
                                            }),
                                          )
                                        : _workspaceView == 'settings'
                                            ? SettingsPage(
                                                isDark: widget.isDark,
                                                accent: widget.accent,
                                                initialSection:
                                                    _settingsInitialSection,
                                                onToggleTheme:
                                                    widget.onToggleTheme,
                                              )
                                            : _workspaceView == 'canvas'
                                                ? CanvasView(
                                                    notes: _notes,
                                                    canvases: _canvases,
                                                    selectedCanvasId:
                                                        _selectedCanvasId,
                                                    onCanvasChanged: (id) =>
                                                        setState(() =>
                                                            _selectedCanvasId =
                                                                id),
                                                    onPositionsChanged:
                                                        _saveCanvasLayout,
                                                    onCreateCanvas:
                                                        _createCanvas,
                                                    onSubmitQuiz:
                                                        _submitCanvasQuiz,
                                                    onSelect: (note) =>
                                                        setState(() {
                                                      _selected = note;
                                                      _workspaceView = 'notes';
                                                    }),
                                                  )
                                                : _workspaceView == 'graph'
                                                    ? KnowledgeGraph(
                                                        notes: _notes,
                                                        onSelect: (note) =>
                                                            setState(() {
                                                          _selected = note;
                                                          _workspaceView =
                                                              'notes';
                                                        }),
                                                        onAddLink: _addNoteLink,
                                                        onRemoveLink:
                                                            _removeNoteLink,
                                                      )
                                                    : _selected == null
                                                        ? WorkspaceWelcome(
                                                            onCreate:
                                                                _createNote)
                                                        : NoteEditor(
                                                            key: ValueKey(
                                                                _selected!.id),
                                                            note: _selected!,
                                                            folders: _folders,
                                                            onSave: _save,
                                                            onMove: _moveNote,
                                                            onUploadImage:
                                                                _uploadImage,
                                                          ),
                      ),
                    ],
                  ),
                ),
                if (showAgentBeside)
                  CoachPanel(
                      key: ValueKey(_chatOpenRevision),
                      note: _selected,
                      onWorkspaceChanged: _load,
                      onChatSaved: _saveRecentChat,
                      onChatDeleted: _removeRecentChat,
                      onSwitchApi: _openAiSettings,
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
                  key: ValueKey(_chatOpenRevision),
                  note: _selected,
                  onWorkspaceChanged: _load,
                  onChatSaved: _saveRecentChat,
                  onChatDeleted: _removeRecentChat,
                  onSwitchApi: _openAiSettings,
                  onClose: () => setState(() => _agentOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail(
      {required this.view, required this.onMenu, required this.onSelect});
  final String view;
  final VoidCallback onMenu;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).extension<LumiTokens>()!.surface,
          border:
              Border(right: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: IconButton(
                tooltip: 'Open workspace navigation',
                onPressed: onMenu,
                icon: const Icon(LucideIcons.menu)),
          ),
          _RailItem(
              icon: LucideIcons.house,
              label: 'Home',
              selected: view == 'home',
              onTap: () => onSelect('home')),
          _RailItem(
              icon: LucideIcons.library,
              label: 'Artifacts',
              selected: view == 'artifacts',
              onTap: () => onSelect('artifacts')),
          _RailItem(
              icon: LucideIcons.layoutDashboard,
              label: 'Canvas',
              selected: view == 'canvas',
              onTap: () => onSelect('canvas')),
          _RailItem(
              icon: LucideIcons.network,
              label: 'Graph',
              selected: view == 'graph',
              onTap: () => onSelect('graph')),
          const Spacer(),
          _RailItem(
              icon: LucideIcons.slidersHorizontal,
              label: 'Settings',
              selected: view == 'settings',
              onTap: () => onSelect('settings')),
          const SizedBox(height: 12),
        ]),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              foregroundColor: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: onTap,
            isSelected: selected,
            icon: Icon(icon),
          ),
        ),
      );
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

class _NoPageTransition extends PageTransitionsBuilder {
  const _NoPageTransition();
  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}

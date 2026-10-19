import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/app_settings.dart';
import '../data/lumi_api.dart';
import 'ai_connection_settings.dart';
import 'canvas_background.dart';
import 'canvas_color_editor.dart';
import 'lumi_theme.dart';
import 'settings_controller.dart';
import 'settings_download.dart';
import 'hardware_report.dart';

const settingsSections =
    <({String title, String subtitle, IconData icon, String search})>[
  (
    title: 'General',
    subtitle: 'Make this workspace your own.',
    icon: LucideIcons.slidersHorizontal,
    search: 'name profile startup home'
  ),
  (
    title: 'Appearance',
    subtitle: 'A comfortable space for focused thinking.',
    icon: LucideIcons.palette,
    search:
        'theme dark light color colour accent text density motion canvas background pattern dots grid'
  ),
  (
    title: 'AI & models',
    subtitle: 'Choose the intelligence behind your learning.',
    icon: LucideIcons.sparkles,
    search: 'provider model ollama api key connection'
  ),
  (
    title: 'Learning & coach',
    subtitle: 'Learning that adapts to the way you think.',
    icon: LucideIcons.graduationCap,
    search: 'difficulty questions teaching style context'
  ),
  (
    title: 'Workspace & editor',
    subtitle: 'Shape your writing and organization tools.',
    icon: LucideIcons.panelsTopLeft,
    search: 'save autosave spelling preview recent files'
  ),
  (
    title: 'Artifacts & storage',
    subtitle: 'Everything you create, thoughtfully collected.',
    icon: LucideIcons.archive,
    search: 'library grid list sort backup export'
  ),
  (
    title: 'Privacy & data',
    subtitle: 'Understand and control what Lumi remembers.',
    icon: LucideIcons.shieldCheck,
    search: 'preferences delete forget reset personal data'
  ),
  (
    title: 'About & diagnostics',
    subtitle: 'A little about Lumi, and how it is running.',
    icon: LucideIcons.info,
    search: 'version service health licenses report'
  ),
  (
    title: 'Hardware report',
    subtitle: 'A clear inventory of the computer running Lumi.',
    icon: LucideIcons.cpu,
    search:
        'hardware cpu processor ram memory nvidia amd intel gpu graphics disk storage ollama'
  ),
];

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {required this.isDark,
      required this.accent,
      required this.onToggleTheme,
      this.initialSection = 0,
      this.api,
      super.key});
  final LumiApi? api;
  final bool isDark;
  final LumiAccent accent;
  final VoidCallback onToggleTheme;
  final int initialSection;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _api = widget.api ?? LumiApi();
  final _scroll = ScrollController();
  SettingsController? _controller;
  bool _ownsController = false, _busy = false, _saving = false, _saved = false;
  late int _section =
          widget.initialSection.clamp(0, settingsSections.length - 1),
      _formRevision = 0;
  String _query = '';
  late bool _canvasDark = widget.isDark;
  String? _notice;
  bool _failed = false;
  late final Map<String, dynamic> _patch;
  Map<String, dynamic>? _diagnostics;
  List<String>? _preferences;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = AppSettingsScope.maybeOf(context);
    if (_controller == null) {
      _ownsController = true;
      _controller = SettingsController();
      _controller!.load();
    }
    _patch = _controller!.pending;
    _controller!.addListener(_refresh);
    _loadInformation();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _formRevision++;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    if (_ownsController) _controller?.dispose();
    _api.close();
    _scroll.dispose();
    super.dispose();
  }

  dynamic _value(String key) =>
      _patch[key] ?? _controller!.settings.values[key];
  void _change(String key, dynamic value) => setState(() {
        if (value == _controller!.settings.values[key]) {
          _patch.remove(key);
        } else {
          _patch[key] = value;
        }
        _notice = null;
        _saved = false;
      });
  Future<void> _loadInformation() async {
    try {
      final values = await Future.wait(
          [_api.settingsResource('/api/workspace/status'), _api.preferences()]);
      if (!mounted) return;
      setState(() {
        _diagnostics = values[0] as Map<String, dynamic>;
        _preferences = values[1] as List<String>;
      });
    } on Object {
      /* Each page exposes a retry when the local service is unavailable. */
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _notice = success;
          _failed = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _notice = error.toString();
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_patch.isEmpty || _busy) return;
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      await _run(() async {
        await _controller!.save(Map.of(_patch));
        if (mounted) setState(() => _formRevision++);
      }, 'Changes saved. Your preferences are ready.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = !_failed && _patch.isEmpty;
        });
      }
    }
  }

  void _select(int value) {
    setState(() {
      _section = value;
      _notice = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _export() => _run(() async {
        final data = await _api.settingsResource('/api/workspace/export');
        await downloadSettingsFile(
            'lumi-workspace-${DateTime.now().toIso8601String().substring(0, 10)}.json',
            const JsonEncoder.withIndent('  ').convert(data));
      }, 'Workspace export downloaded. Store it somewhere private.');
  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Forget preferences')),
              ])) ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = List.generate(settingsSections.length, (i) => i)
        .where((i) =>
            '${settingsSections[i].title} ${settingsSections[i].search}'
                .toLowerCase()
                .contains(_query))
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 820;
      final nav =
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            decoration: const InputDecoration(
                hintText: 'Search settings',
                prefixIcon: Icon(LucideIcons.search, size: 17)),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase())),
        const SizedBox(height: 16),
        if (sections.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No matching settings.')),
        if (narrow && sections.isNotEmpty)
          DropdownButtonFormField<int>(
              key: ValueKey('category-$_section-$_query'),
              initialValue:
                  sections.contains(_section) ? _section : sections.first,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Settings section'),
              items: sections
                  .map((i) => DropdownMenuItem(
                      value: i, child: Text(settingsSections[i].title)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _select(value);
              }),
        if (!narrow)
          ...sections.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                  selected: _section == i,
                  selectedTileColor:
                      theme.colorScheme.primary.withValues(alpha: .09),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  leading: Icon(settingsSections[i].icon, size: 18),
                  minLeadingWidth: 18,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(settingsSections[i].title,
                      style: const TextStyle(fontSize: 13)),
                  onTap: () => _select(i)))),
      ]);
      final content =
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: ListView(
                controller: _scroll,
                padding: EdgeInsets.all(narrow ? 20 : 32),
                children: [
              Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('YOUR WORKSPACE, YOUR WAY',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.8,
                                    color: theme.colorScheme.primary)),
                            const SizedBox(height: 12),
                            Text(settingsSections[_section].title,
                                style: theme.textTheme.headlineLarge
                                    ?.copyWith(fontSize: narrow ? 29 : 34)),
                            const SizedBox(height: 8),
                            Text(settingsSections[_section].subtitle,
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 28),
                            if (!_controller!.loaded)
                              const LinearProgressIndicator(),
                            if (_controller!.error != null)
                              _noticeCard(_controller!.error!,
                                  error: true,
                                  action: TextButton(
                                      onPressed:
                                          _busy ? null : _controller!.load,
                                      child: const Text('Retry'))),
                            if (_notice != null)
                              Semantics(
                                  liveRegion: true,
                                  child: _noticeCard(_notice!, error: _failed)),
                            ..._body(),
                            const SizedBox(height: 20),
                            Text('Lumi · A quieter place to learn',
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center),
                          ]))),
            ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.dividerColor))),
            child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text(_patch.isEmpty
                      ? (_saved ? 'All changes saved' : 'No unsaved changes')
                      : '${_patch.length} unsaved ${_patch.length == 1 ? 'change' : 'changes'}'),
                  TextButton(
                      onPressed: _busy || _patch.isEmpty
                          ? null
                          : () => setState(() {
                                _saved = false;
                                _patch.clear();
                                _formRevision++;
                              }),
                      child: const Text('Discard')),
                  FilledButton.icon(
                      onPressed: _busy ||
                              _patch.isEmpty ||
                              !_controller!.loaded ||
                              _controller!.error != null
                          ? null
                          : _save,
                      icon: Icon(
                          _saving ? LucideIcons.loader : LucideIcons.check,
                          size: 16),
                      label: Text(_saving
                          ? 'Saving…'
                          : _saved && _patch.isEmpty
                              ? 'Saved'
                              : 'Save changes')),
                ])),
      ]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 20 : 28, 22, 24, 20),
            child: Row(children: [
              Icon(LucideIcons.settings,
                  size: 21, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Settings', style: theme.textTheme.titleLarge)
            ])),
        Divider(height: 1, color: theme.dividerColor),
        if (narrow)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: nav),
        Expanded(
            child: narrow
                ? content
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Container(
                            width: 232,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                border: Border(
                                    right:
                                        BorderSide(color: theme.dividerColor))),
                            child: SingleChildScrollView(child: nav)),
                        Expanded(child: content),
                      ])),
      ]);
    });
  }

  List<Widget> _body() => switch (_section) {
        0 => [
            _card('Personal details',
                'A familiar name for your learning space.', [
              _input('displayName', 'Your name',
                  'Used when you ask the coach for help.'),
              _input('workspaceName', 'Workspace name',
                  'Shown in your workspace sidebar.'),
            ]),
            _card('Start your day',
                'Choose where Lumi opens on your next visit.', [
              _choice('startPage', 'Start page', {
                'home': 'Home',
                'artifacts': 'Artifacts library',
                'canvas': 'Canvases',
                'notes': 'Note editor'
              }),
            ]),
            _noticeCard(
                'Your content stays in the local Lumi service. Connecting a cloud model sends your requests and selected note context to that provider.'),
          ],
        1 => [
            _card('Color & theme', 'Find the right light for your work.', [
              _choice('theme', 'Theme', {
                'light': 'Warm paper',
                'dark': 'Evening sage',
                'system': 'Follow system'
              }),
              _toggle('rotateAccent', 'Rotate accent on startup',
                  'Cycle through Lumi’s four accent colors on each web startup.'),
              _choice(
                  'accent',
                  'Accent color',
                  {
                    for (final accent in LumiAccent.values)
                      accent.name: accent.label
                  },
                  enabled: _value('rotateAccent') == false),
            ]),
            _canvasAppearance(),
            _card('Reading comfort',
                'Adjust the interface across your workspace.', [
              _choice('textSize', 'Interface text size', {
                'small': 'Small · 90%',
                'standard': 'Standard · 100%',
                'large': 'Large · 115%'
              }),
              _choice('density', 'Interface density',
                  {'comfortable': 'Comfortable', 'compact': 'Compact'}),
              _toggle('reduceMotion', 'Reduce motion',
                  'Remove theme and page transition animations.'),
            ]),
          ],
        2 => [const AiConnectionSettings()],
        3 => [
            _card(
                'Your learning defaults',
                'Applied as instructions to new coach requests. You can override them in your message.',
                [
                  _choice('teachingStyle', 'Teaching style', {
                    'balanced': 'Balanced explanations',
                    'concise': 'Concise & direct',
                    'step-by-step': 'Step by step',
                    'socratic': 'Socratic questions'
                  }),
                  _choice('difficulty', 'Learning level', {
                    'adaptive': 'Adapt to me',
                    'beginner': 'Beginner',
                    'intermediate': 'Intermediate',
                    'advanced': 'Advanced'
                  }),
                  _choice('questionCount', 'Default assessment length', {
                    for (final count in List.generate(20, (i) => i + 1))
                      count: '$count questions'
                  }),
                ]),
            _card('Coach context',
                'Choose the information included with your messages.', [
              _toggle('coachContext', 'Include the active note',
                  'Send the current note’s title and content with coach requests.'),
              _toggle('rememberPreferences', 'Use remembered preferences',
                  'Save explicit learning preferences from your messages and apply saved preferences to replies. Existing preferences are kept when off. Earlier chat messages may still contain context; start a new conversation for a fresh context.'),
            ]),
          ],
        4 => [
            _card('Writing experience', 'Keep your attention on the ideas.', [
              _choice('editorMode', 'Open notes in',
                  {'edit': 'Plain text editor', 'preview': 'Rendered preview'}),
              _choice('editorWidth', 'Writing width',
                  {'focused': 'Focused · 800 px', 'wide': 'Wide · 1120 px'}),
              _toggle('spellcheck', 'Writing suggestions',
                  'Enable browser autocorrection and spelling suggestions where supported.'),
            ]),
            _card('Saving & navigation',
                'Notes save automatically, with browser drafts for recovery.', [
              _choice('autosaveDelay', 'Autosave after typing stops', {
                500: '0.5 seconds',
                700: '0.7 seconds',
                1500: '1.5 seconds',
                3000: '3 seconds'
              }),
              _choice('recentLimit', 'Recent conversations', {
                5: '5 conversations',
                12: '12 conversations',
                20: '20 conversations'
              }),
            ]),
          ],
        5 => [
            _card(
                'Artifacts library',
                'Your academic objects remain archived when their source is removed.',
                [
                  _choice('artifactLayout', 'Default view',
                      {'grid': 'Card grid', 'list': 'Detailed list'}),
                  _choice('artifactSort', 'Default sort order', {
                    'Newest first': 'Newest first',
                    'Oldest first': 'Oldest first',
                    'Title A–Z': 'Title A–Z'
                  }),
                ]),
            _card(
                'Local storage', 'Live counts from your local Lumi service.', [
              _storage(),
            ]),
            _card(
                'Take a copy with you',
                'Export notes, folders, full canvases, assessment data, archived artifacts, preferences and attached images as JSON. Provider credentials and chat session files are excluded.',
                [
                  _action('Download workspace export', LucideIcons.download,
                      _export),
                  const SizedBox(height: 10),
                  const Text(
                      'This is a data export. Automatic backup scheduling and restoring exports are not available in this version.'),
                ]),
          ],
        6 => [
            _card(
                'What Lumi remembers',
                'Only learning preferences you explicitly state are saved. Removing a preference cannot be undone.',
                [
                  if (_preferences == null)
                    _retryInformation()
                  else if (_preferences!.isEmpty)
                    const Text('No remembered preferences yet.')
                  else
                    ..._preferences!.map((preference) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(preference),
                        trailing: IconButton(
                            tooltip: 'Forget preference',
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                      final next = await _api
                                          .forgetPreference(preference);
                                      if (mounted) {
                                        setState(() => _preferences = next);
                                      }
                                    }, 'Preference forgotten.')))),
                  const SizedBox(height: 12),
                  _action(
                      'Forget all learning preferences',
                      LucideIcons.eraser,
                      _preferences == null || _preferences!.isEmpty
                          ? null
                          : () async {
                              if (!await _confirm(
                                  'Forget all learning preferences?',
                                  'This removes remembered teaching preferences. Notes, artifacts, assessment records and provider settings are preserved.')) {
                                return;
                              }
                              await _run(() async {
                                await _api.clearPreferences();
                                if (mounted) setState(() => _preferences = []);
                              }, 'All learning preferences forgotten.');
                            }),
                ]),
            _card('Your data, clearly',
                'Lumi stores content on the computer running its backend.', [
              const Text(
                  'Cloud AI providers receive the messages and context you send. Turn off active note context in Learning & coach to send only your request. API keys are stored by the backend and are never returned to the browser.'),
              const SizedBox(height: 16),
              _action(
                  'Export my workspace data', LucideIcons.download, _export),
            ]),
            _card(
                'Reset application preferences',
                'Restore the interface and learning defaults. Your content and provider connection are preserved.',
                [
                  _action('Review default preferences', LucideIcons.rotateCcw,
                      () {
                    setState(() {
                      _formRevision++;
                      _patch.clear();
                      for (final entry in AppSettings.defaults.entries) {
                        if (_controller!.settings.values[entry.key] !=
                            entry.value) {
                          _patch[entry.key] = entry.value;
                        }
                      }
                      _notice =
                          'Defaults staged. Save changes to apply, or Discard to keep your preferences.';
                      _failed = false;
                    });
                  }),
                ]),
          ],
        8 => [HardwareReport(api: _api)],
        _ => [
            _card('Made for a curious mind', 'Lumi · Think. Connect. Learn.', [
              Text('Version 0.1.0+1',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              const Text(
                  'A local-first academic workspace with notes, connected canvases, a complete artifacts library and Genkit-powered learning agents.'),
            ]),
            _card(
                'Service diagnostics',
                'Connection availability does not imply a successful AI generation. Use Test connection in AI & models to verify your provider.',
                [
                  if (_diagnostics == null)
                    _retryInformation()
                  else
                    ...['service', 'provider', 'model'].map((key) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                            '${key[0].toUpperCase()}${key.substring(1)}: ${_diagnostics![key]}'))),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _action(
                        'Refresh diagnostics',
                        LucideIcons.refreshCw,
                        () => _run(() async {
                              final result = await _api
                                  .settingsResource('/api/workspace/status');
                              if (mounted) {
                                setState(() => _diagnostics = result);
                              }
                            }, 'Diagnostics refreshed.')),
                    _action(
                        'Copy diagnostic report',
                        LucideIcons.copy,
                        _diagnostics == null
                            ? null
                            : () => _run(
                                () => Clipboard.setData(ClipboardData(
                                    text: const JsonEncoder.withIndent('  ')
                                        .convert(_diagnostics))),
                                'Diagnostic report copied. No credentials or content included.')),
                  ]),
                ]),
            _card(
                'Open source',
                'Built with Flutter, Dart and Genkit. Typography by DM Sans and Lora.',
                [
                  _action(
                      'View licenses',
                      LucideIcons.fileText,
                      () => showLicensePage(
                          context: context,
                          applicationName: 'Lumi',
                          applicationVersion: '0.1.0+1')),
                ]),
          ],
      };

  Widget _canvasAppearance() {
    final values = {..._controller!.settings.values, ..._patch};
    for (final key in AppSettings.canvasColorKeys) {
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(values[key] as String)) {
        values[key] = _controller!.settings.text(key);
      }
    }
    final suffix = _canvasDark ? 'Dark' : 'Light';
    return _card(
        'Canvas',
        'A quiet backdrop for your notes and quizzes. Colours are saved separately for light and dark themes.',
        [
          _choice('canvasPattern', 'Background pattern', {
            'dots': 'Dot grid',
            'grid': 'Square grid',
            'none': 'Plain',
          }),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: DropdownButtonFormField<bool>(
              initialValue: _canvasDark,
              decoration: const InputDecoration(labelText: 'Edit colours for'),
              items: const [
                DropdownMenuItem(value: false, child: Text('Light theme')),
                DropdownMenuItem(value: true, child: Text('Dark theme')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _canvasDark = value ?? false),
            ),
          ),
          for (final (key, label) in [
            ('canvasBackground$suffix', 'Canvas background'),
            ('canvasPattern$suffix', 'Pattern colour'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: CanvasColorEditor(
                key: ValueKey('$key-$_formRevision'),
                label: label,
                value: _value(key) as String,
                onChanged: (value) => _change(key, value),
                enabled: !_busy,
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                height: 150,
                child: Theme(
                  data: _canvasDark
                      ? LumiTheme.dark(accent: widget.accent)
                      : LumiTheme.light(accent: widget.accent),
                  child: Builder(
                      builder: (previewContext) => CanvasBackground(
                            settings: AppSettings(values),
                            child: Center(
                                child: Card(
                                    child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Your ideas, connected.',
                                  style: Theme.of(previewContext)
                                      .textTheme
                                      .titleMedium),
                            ))),
                          )),
                )),
          ),
          const SizedBox(height: 8),
          const Text('Preview · Save changes to apply to all canvases.'),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        for (final key in [
                          'canvasPattern',
                          ...AppSettings.canvasColorKeys
                        ]) {
                          _change(key, AppSettings.defaults[key]);
                        }
                        setState(() => _formRevision++);
                      },
                child: const Text('Reset Canvas appearance'),
              )),
        ]);
  }

  Widget _storage() {
    if (_diagnostics == null) return _retryInformation();
    final bytes = (_diagnostics!['storageBytes'] as num?) ?? 0;
    final usage = bytes < 1024
        ? '${bytes.toInt()} B'
        : bytes < 1024 * 1024
            ? '${(bytes / 1024).toStringAsFixed(1)} KB'
            : '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$usage on disk', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Wrap(spacing: 20, runSpacing: 12, children: [
        for (final key in ['notes', 'folders', 'canvases', 'artifacts'])
          Chip(
              label: Text(
                  '${_diagnostics![key]} ${_diagnostics![key] == 1 ? key.substring(0, key.length - 1) : key}'))
      ]),
      const SizedBox(height: 12),
      _action(
          'Refresh storage',
          LucideIcons.refreshCw,
          () => _run(() async {
                final result =
                    await _api.settingsResource('/api/workspace/status');
                if (mounted) setState(() => _diagnostics = result);
              }, 'Storage counts refreshed.')),
    ]);
  }

  Widget _retryInformation() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Local service information is unavailable.'),
        TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await _loadInformation();
                      if (_diagnostics == null || _preferences == null) {
                        throw StateError('The local service is unavailable.');
                      }
                    }, 'Service information refreshed.'),
            child: const Text('Retry'))
      ]);
  Widget _action(String label, IconData icon, VoidCallback? action) =>
      OutlinedButton.icon(
          onPressed: _busy ? null : action,
          icon: Icon(icon, size: 16),
          label: Text(label));
  Widget _noticeCard(String message,
          {bool error = false, Widget? action}) =>
      Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: (error
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary)
                  .withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(message), if (action != null) action]));
  Widget _card(String title, String subtitle, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.5)),
                    const SizedBox(height: 22),
                    ...children
                  ]))));
  Widget _input(String key, String label, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
          key: ValueKey('$key-$_formRevision'),
          initialValue: _value(key) as String,
          maxLength: 80,
          decoration: InputDecoration(
              labelText: label, helperText: hint, helperMaxLines: 3),
          onChanged: (value) => _change(key, value)));
  Widget _choice<T extends Object>(
          String key, String label, Map<T, String> options,
          {bool enabled = true}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: DropdownButtonFormField<T>(
              key: ValueKey('$key-${_value(key)}-$enabled'),
              initialValue: _value(key) as T,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: options.entries
                  .map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child:
                          Text(entry.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _busy || !enabled
                  ? null
                  : (value) {
                      if (value != null) _change(key, value);
                    }));
  Widget _toggle(String key, String label, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child:
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall)),
          value: _value(key) as bool,
          onChanged: _busy ? null : (value) => _change(key, value)));
}

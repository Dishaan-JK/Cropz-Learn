import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import 'note_editor.dart';
import 'learning_object_player.dart';
import 'settings_controller.dart';

const artifactKinds = [
  'Notes',
  'Canvases',
  'Lessons',
  'Quizzes',
  'Test papers',
  'Revision exams',
  'Flashcards',
  'Revision plans',
  'Reviews',
  'Explanations'
];

class ArtifactsPage extends StatefulWidget {
  const ArtifactsPage(
      {required this.load,
      required this.revision,
      required this.onCreate,
      required this.onCoach,
      required this.onOpenSource,
      required this.hasSource,
      this.submitQuiz,
      super.key});
  final Future<List<AcademicArtifact>> Function() load;
  final Future<Map<String, dynamic>> Function(String, List<int>)? submitQuiz;
  final int revision;
  final VoidCallback onCreate, onCoach;
  final ValueChanged<AcademicArtifact> onOpenSource;
  final bool Function(AcademicArtifact) hasSource;

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
  List<AcademicArtifact> _items = [];
  final _search = TextEditingController();
  String _query = '', _kind = 'All', _sort = 'Newest first';
  bool _list = false, _loading = true;
  String? _error;
  int _request = 0;
  bool _appliedDefaults = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appliedDefaults) {
      final settings = AppSettingsScope.settingsOf(context);
      _list = settings.text('artifactLayout') == 'list';
      _sort = settings.text('artifactSort');
      _appliedDefaults = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtifactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error =
            'Your library could not be loaded. Check the local service and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _items
        .where((a) =>
            (_kind == 'All' || a.kind == _kind) &&
            '${a.title} ${a.content} ${a.kind} ${a.source}'
                .toLowerCase()
                .contains(_query))
        .toList()
      ..sort((a, b) => switch (_sort) {
            'Title A–Z' =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            'Oldest first' => a.updatedAt.compareTo(b.updatedAt),
            _ => b.updatedAt.compareTo(a.updatedAt),
          });
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 600;
      return CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              narrow ? 20 : 40, narrow ? 28 : 40, narrow ? 20 : 40, 20),
          sliver: SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('YOUR LIBRARY',
                    style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 12),
                Text('Your learning, collected.',
                    style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: narrow ? 29 : 36, letterSpacing: -1)),
                const SizedBox(height: 12),
                Text(
                    'One home for your notes, ideas, and everything you learn with Lumi.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 24),
                Wrap(spacing: 24, runSpacing: 8, children: [
                  _LibraryStat(
                      value: '${_items.length}', label: 'saved artifacts'),
                  _LibraryStat(
                      value: '${_items.map((a) => a.kind).toSet().length}',
                      label: 'material types'),
                  const _LibraryStat(
                      value: 'Local', label: 'stored on this computer'),
                ]),
                const SizedBox(height: 28),
                TextField(
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.search, size: 20),
                        labelText: 'Search artifacts',
                        hintText: 'Search titles, content, and sources',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(LucideIcons.x, size: 18)))),
                const SizedBox(height: 18),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final kind in ['All', ...artifactKinds])
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                  '$kind  ${kind == 'All' ? _items.length : _items.where((a) => a.kind == kind).length}'),
                              selected: _kind == kind,
                              onSelected: (_) => setState(() => _kind = kind),
                              showCheckmark: false,
                            )),
                    ])),
                const SizedBox(height: 20),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                          '${visible.length} ${visible.length == 1 ? 'artifact' : 'artifacts'}',
                          style: theme.textTheme.labelLarge),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButton<String>(
                            value: _sort,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final sort in [
                                'Newest first',
                                'Oldest first',
                                'Title A–Z'
                              ])
                                DropdownMenuItem(
                                    value: sort,
                                    child: Text(sort,
                                        style: theme.textTheme.bodySmall))
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _sort = value);
                            }),
                        const SizedBox(width: 8),
                        IconButton(
                            tooltip: 'Grid view',
                            isSelected: !_list,
                            onPressed: () => setState(() => _list = false),
                            icon: const Icon(LucideIcons.layoutGrid, size: 18)),
                        IconButton(
                            tooltip: 'List view',
                            isSelected: _list,
                            onPressed: () => setState(() => _list = true),
                            icon: const Icon(LucideIcons.list, size: 18)),
                        IconButton(
                            tooltip: 'Refresh artifacts',
                            onPressed: _loading ? null : _load,
                            icon: const Icon(LucideIcons.refreshCw, size: 18)),
                      ]),
                    ]),
              ])),
        ),
        if (_loading)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator())))
        else if (_error != null)
          SliverToBoxAdapter(
              child: _LibraryEmpty(
                  icon: LucideIcons.wifiOff,
                  title: 'Let’s reconnect your library',
                  message: _error!,
                  action: FilledButton(
                      onPressed: _load, child: const Text('Try again'))))
        else if (visible.isEmpty)
          SliverToBoxAdapter(
              child: _LibraryEmpty(
                  icon: LucideIcons.library,
                  title: _items.isEmpty
                      ? 'A home for everything you learn'
                      : 'No matching artifacts',
                  message: _items.isEmpty
                      ? 'Create a note or ask Lumi Coach for a lesson, quiz, or study material. It will be saved here automatically.'
                      : 'Try another search or choose a different material type.',
                  action: _items.isEmpty
                      ? Wrap(spacing: 12, runSpacing: 12, children: [
                          FilledButton.icon(
                              onPressed: widget.onCreate,
                              icon: const Icon(LucideIcons.plus, size: 18),
                              label: const Text('Create a note')),
                          OutlinedButton.icon(
                              onPressed: widget.onCoach,
                              icon: const Icon(LucideIcons.sparkles, size: 18),
                              label: const Text('Ask Lumi Coach')),
                        ])
                      : TextButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _query = '';
                              _kind = 'All';
                            });
                          },
                          child: const Text('Clear filters'))))
        else
          SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  narrow ? 20 : 40, 0, narrow ? 20 : 40, 40),
              sliver: _list
                  ? SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ArtifactCard(
                              artifact: visible[i],
                              compact: true,
                              onTap: () => _read(visible[i]))))
                  : SliverLayoutBuilder(
                      builder: (context, grid) => SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: (grid.crossAxisExtent / 290)
                                      .floor()
                                      .clamp(1, 4),
                                  mainAxisExtent: 264,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18),
                          itemCount: visible.length,
                          itemBuilder: (context, i) => _ArtifactCard(
                              artifact: visible[i],
                              onTap: () => _read(visible[i]))))),
      ]);
    });
  }

  Future<void> _read(AcademicArtifact artifact) => showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final narrow = MediaQuery.sizeOf(dialogContext).width < 600;
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: EdgeInsets.all(narrow ? 12 : 36),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840, maxHeight: 900),
              child: Padding(
                  padding: EdgeInsets.all(narrow ? 20 : 32),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  '${artifact.kind} · ${artifact.source}',
                                  style: theme.textTheme.labelMedium)),
                          IconButton(
                              tooltip: 'Close artifact',
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(LucideIcons.x))
                        ]),
                        const SizedBox(height: 8),
                        Text(artifact.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('Saved ${_date(artifact.updatedAt)}',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: artifact.learningObject != null
                                    ? LearningObjectPlayer(
                                        object: artifact.learningObject!,
                                        artifactId: artifact.id,
                                        submitQuiz: widget.submitQuiz)
                                    : SelectionArea(
                                        child: MarkdownPreview(
                                            content: artifact.content.isEmpty
                                                ? 'This artifact has no text yet.'
                                                : artifact.content)))),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: artifact.content));
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(const SnackBar(
                                        content: Text('Artifact copied')));
                              },
                              icon: const Icon(LucideIcons.copy, size: 16),
                              label: const Text('Copy text')),
                          if (widget.hasSource(artifact))
                            FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  widget.onOpenSource(artifact);
                                },
                                icon: const Icon(LucideIcons.externalLink,
                                    size: 16),
                                label: const Text('Open in workspace')),
                        ]),
                      ]))),
        );
      });
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Flexible(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      ]);
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard(
      {required this.artifact, required this.onTap, this.compact = false});
  final AcademicArtifact artifact;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (artifact.kind) {
      'Notes' => LucideIcons.fileText,
      'Canvases' => LucideIcons.layoutDashboard,
      'Quizzes' || 'Test papers' => LucideIcons.clipboardCheck,
      'Flashcards' => LucideIcons.layers,
      'Reviews' => LucideIcons.chartNoAxesCombined,
      'Revision plans' => LucideIcons.calendarDays,
      _ => LucideIcons.bookOpen,
    };
    final tile = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20));
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: compact
                    ? Row(children: [
                        tile,
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Text(artifact.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                  '${artifact.kind}${artifact.learningObject != null ? ' · Interactive' : ''} · ${_date(artifact.updatedAt)}',
                                  style: theme.textTheme.bodySmall),
                            ])),
                        const Icon(LucideIcons.chevronRight, size: 18)
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(children: [
                              tile,
                              const Spacer(),
                              Text(
                                  artifact.learningObject != null
                                      ? 'Interactive'
                                      : artifact.kind,
                                  style: theme.textTheme.labelSmall)
                            ]),
                            const SizedBox(height: 18),
                            Text(artifact.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontSize: 18)),
                            const SizedBox(height: 10),
                            Expanded(
                                child: Text(
                                    artifact.content.isEmpty
                                        ? 'Ready for your next idea.'
                                        : artifact.content
                                            .replaceAll(
                                                RegExp(r'[#*`\[\]]'), '')
                                            .replaceAll(RegExp(r'\s+'), ' '),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        height: 1.6,
                                        color: theme
                                            .colorScheme.onSurfaceVariant))),
                            const Divider(height: 24),
                            Row(children: [
                              Expanded(
                                  child: Text(artifact.source,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall)),
                              Text(_date(artifact.updatedAt),
                                  style: theme.textTheme.labelSmall),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.arrowUpRight, size: 16)
                            ]),
                          ]))));
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty(
      {required this.icon,
      required this.title,
      required this.message,
      required this.action});
  final IconData icon;
  final String title, message;
  final Widget action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6))),
        const SizedBox(height: 24),
        action
      ]));
}

String _date(DateTime date) {
  final local = date.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

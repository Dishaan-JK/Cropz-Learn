import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import 'app_config.dart';
import 'folder_labels.dart';
import 'appearance_storage.dart';
import 'settings_controller.dart';
import 'note_editor_platform.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor(
      {required this.note,
      required this.folders,
      required this.onSave,
      required this.onMove,
      required this.onUploadImage,
      super.key});
  final Note note;
  final List<Folder> folders;
  final Future<bool> Function(Note, String, String) onSave;
  final Future<void> Function(Note, String?) onMove;
  final Future<String> Function(String, String) onUploadImage;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  Timer? _saveTimer;
  bool _preview = false;
  bool _appliedDefaults = false;
  int _autosaveDelay = 700;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppSettingsScope.settingsOf(context);
    _autosaveDelay = settings.number('autosaveDelay');
    if (!_appliedDefaults) {
      _preview = settings.text('editorMode') == 'preview';
      _appliedDefaults = true;
    }
  }

  bool _slashMenuOpen = false;
  bool _dirty = false;
  int _editRevision = 0;

  String get _draftKey => 'lumi.note.draft.${widget.note.id}';
  int? _slashStart;

  void _insertMarkup(String prefix, [String suffix = '']) {
    final value = _content.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final replacement = selected.isEmpty ? 'text' : selected;
    final inserted = '$prefix$replacement$suffix';
    final text = value.text.replaceRange(start, end, inserted);
    _content.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: start + prefix.length + replacement.length,
      ),
    );
    _content.selection = TextSelection.collapsed(
      offset: start + prefix.length + replacement.length,
    );
  }

  void _insertSnippet(String text) {
    final value = _content.value;
    final start =
        value.selection.isValid ? value.selection.start : value.text.length;
    final end =
        value.selection.isValid ? value.selection.end : value.text.length;
    final inserted =
        start > 0 && value.text[start - 1] != '\n' ? '\n$text' : text;
    final next = value.text.replaceRange(start, end, inserted);
    _content.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
  }

  @override
  void initState() {
    super.initState();
    final draft = _readDraft();
    _title = TextEditingController(
        text: draft?['title'] as String? ?? widget.note.title);
    _content = TextEditingController(
        text: draft?['content'] as String? ?? widget.note.content);
    _title.addListener(_scheduleSave);
    _content.addListener(_onContentChanged);
    if (draft != null) _scheduleSave();
  }

  void _scheduleSave() {
    _dirty = true;
    _editRevision++;
    _writeDraft();
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(milliseconds: _autosaveDelay), _flushSave);
  }

  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    final revision = _editRevision;
    final saved = await widget.onSave(widget.note, _title.text, _content.text);
    if (saved && revision == _editRevision) {
      try {
        removeAppearanceValue(_draftKey);
      } on Object {
        // The server copy is authoritative even if browser storage is unavailable.
      }
    } else if (!saved) {
      _dirty = true;
      if (mounted) {
        _saveTimer = Timer(const Duration(seconds: 5), _flushSave);
      }
    }
  }

  Map<String, dynamic>? _readDraft() {
    try {
      final raw = readAppearanceValue(_draftKey);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  void _writeDraft() {
    try {
      writeAppearanceValue(
        _draftKey,
        jsonEncode({'title': _title.text, 'content': _content.text}),
      );
    } on Object {
      // Autosave still proceeds when browser storage is blocked or full.
    }
  }

  void _onContentChanged() {
    _scheduleSave();
    final selection = _content.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final cursor = selection.extentOffset;
    final lineStart = _content.text.lastIndexOf('\n', cursor - 1) + 1;
    final command = _content.text.substring(lineStart, cursor);
    final open = RegExp(r'^/[a-zA-Z]*$').hasMatch(command);
    if (_slashMenuOpen != open || (open && _slashStart != lineStart)) {
      setState(() {
        _slashMenuOpen = open;
        _slashStart = open ? lineStart : null;
      });
    }
  }

  void _runSlashCommand(String command) {
    final start = _slashStart;
    final cursor = _content.selection.extentOffset;
    if (start == null) return;
    final snippets = <String, String>{
      'Heading': '## Heading',
      'Bullet list': '- List item',
      'Task': '- [ ] Task',
      'Code block': '```\ncode\n```',
      'Link': '[link text](url)',
      'Math block': '\$\$\nformula\n\$\$',
      'Note link': '[[note title]]',
    };
    final snippet = snippets[command];
    if (snippet != null) {
      final value = _content.value;
      final text = value.text.replaceRange(start, cursor, snippet);
      _content.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start + snippet.length),
      );
    } else if (command == 'Image') {
      final value = _content.value;
      _content.value = TextEditingValue(
        text: value.text.replaceRange(start, cursor, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    }
    setState(() {
      _slashMenuOpen = false;
      _slashStart = null;
    });
    if (command == 'Image') _pickImage();
  }

  Future<void> _pickImage() async {
    final file = await pickImageFile();
    if (file == null || !mounted) return;
    if (file.size > 700 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an image smaller than 700 KB.')),
      );
      return;
    }
    try {
      final path = await widget.onUploadImage(file.base64, file.contentType);
      if (!mounted) return;
      final alt = file.name.replaceAll(RegExp(r'[\]\n\r]'), ' ').trim();
      _insertSnippet('![$alt]($path)');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not attach that image.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty) unawaited(_flushSave());
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth:
                  AppSettingsScope.settingsOf(context).text('editorWidth') ==
                          'wide'
                      ? 1120
                      : 800),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 20 : 48,
              MediaQuery.sizeOf(context).width < 600 ? 24 : 40,
              MediaQuery.sizeOf(context).width < 600 ? 20 : 48,
              32,
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: MediaQuery.sizeOf(context).width < 600
                              ? 26
                              : null,
                        ),
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: 'Untitled note',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Icon(LucideIcons.cloudCheck,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Autosaves to this computer',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Spacer(),
                    DropdownButton<String?>(
                      value: widget.note.folderId,
                      hint: const Text('Unfiled'),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Unfiled')),
                        for (final folder in widget.folders)
                          DropdownMenuItem<String?>(
                            value: folder.id,
                            child: Text(
                              folderPathLabel(folder, widget.folders),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => widget.onMove(widget.note, value),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _EditorTool(
                              icon: LucideIcons.bold,
                              label: 'Bold',
                              onPressed: () => _insertMarkup('**', '**')),
                          _EditorTool(
                              icon: LucideIcons.italic,
                              label: 'Italic',
                              onPressed: () => _insertMarkup('*', '*')),
                          _EditorTool(
                              icon: LucideIcons.heading,
                              label: 'Heading',
                              onPressed: () => _insertSnippet('## Heading')),
                          _EditorTool(
                              icon: LucideIcons.list,
                              label: 'Bullet',
                              onPressed: () => _insertSnippet('- List item')),
                          _EditorTool(
                              icon: LucideIcons.squareCheckBig,
                              label: 'Task',
                              onPressed: () => _insertSnippet('- [ ] Task')),
                          _EditorTool(
                              icon: LucideIcons.code,
                              label: 'Code',
                              onPressed: () => _insertMarkup('`', '`')),
                          _EditorTool(
                              icon: LucideIcons.link2,
                              label: 'Link',
                              onPressed: () => _insertMarkup('[', '](url)')),
                          _EditorTool(
                              icon: LucideIcons.table,
                              label: 'Table',
                              onPressed: () => _insertSnippet(
                                  '| Column 1 | Column 2 |\n| --- | --- |\n| Value | Value |')),
                          _EditorTool(
                              icon: LucideIcons.functionSquare,
                              label: 'Math',
                              onPressed: () =>
                                  _insertSnippet('\$\$\nformula\n\$\$')),
                          _EditorTool(
                              icon: LucideIcons.network,
                              label: 'Note link',
                              onPressed: () => _insertMarkup('[[', ']]')),
                          _EditorTool(
                              icon: LucideIcons.image,
                              label: 'Image',
                              onPressed: _pickImage),
                        ]),
                      ),
                    ),
                    IconButton(
                      tooltip: _preview ? 'Edit source' : 'Preview',
                      onPressed: () => setState(() => _preview = !_preview),
                      icon:
                          Icon(_preview ? LucideIcons.pencil : LucideIcons.eye),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _preview
                        ? MarkdownPreview(content: _content.text)
                        : Stack(children: [
                            TextField(
                              controller: _content,
                              autocorrect: AppSettingsScope.settingsOf(context)
                                  .flag('spellcheck'),
                              enableSuggestions:
                                  AppSettingsScope.settingsOf(context)
                                      .flag('spellcheck'),
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.7),
                              decoration: const InputDecoration(
                                hintText:
                                    'Start writing… Use / for quick formatting commands.',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (_slashMenuOpen)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Material(
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 230,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final item in const [
                                            (
                                              'Heading',
                                              LucideIcons.heading,
                                              '/heading'
                                            ),
                                            (
                                              'Bullet list',
                                              LucideIcons.list,
                                              '/bullet'
                                            ),
                                            (
                                              'Task',
                                              LucideIcons.squareCheckBig,
                                              '/task'
                                            ),
                                            (
                                              'Code block',
                                              LucideIcons.code,
                                              '/code'
                                            ),
                                            (
                                              'Link',
                                              LucideIcons.link2,
                                              '/link'
                                            ),
                                            (
                                              'Math block',
                                              LucideIcons.functionSquare,
                                              '/math'
                                            ),
                                            (
                                              'Note link',
                                              LucideIcons.network,
                                              '/note'
                                            ),
                                            (
                                              'Image',
                                              LucideIcons.image,
                                              '/image'
                                            ),
                                          ])
                                            ListTile(
                                              dense: true,
                                              leading: Icon(item.$2, size: 18),
                                              title: Text(item.$1),
                                              subtitle: Text(item.$3),
                                              onTap: () =>
                                                  _runSlashCommand(item.$1),
                                            ),
                                        ]),
                                  ),
                                ),
                              ),
                          ]),
                  ),
                ]),
          ),
        ),
      );
}

class _EditorTool extends StatelessWidget {
  const _EditorTool(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      );
}

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({required this.content, super.key});
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.65);
    final children = <Widget>[];
    final lines = content.split('\n');
    final code = <String>[];
    final mathLines = <String>[];
    var inCode = false;
    var inMath = false;
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          children.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(code.join('\n'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace', height: 1.5)),
          ));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(line);
        continue;
      }
      if (line.trim() == r'$$') {
        if (inMath) {
          children.add(_mathBlock(theme, mathLines.join('\n')));
          mathLines.clear();
        }
        inMath = !inMath;
        continue;
      }
      if (inMath) {
        mathLines.add(line);
        continue;
      }
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      final image =
          RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(line.trim());
      if (image != null) {
        final alt = image.group(1)!;
        final path = image.group(2)!;
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: path.startsWith('/api/attachments/') && !path.contains('..')
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '$lumiServiceUrl$path',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      alignment: Alignment.center,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Text('Image unavailable'),
                    ),
                  ),
                )
              : Text('Image: $alt', style: theme.textTheme.bodySmall),
        ));
        continue;
      }
      if (line.contains('|') &&
          lineIndex + 1 < lines.length &&
          RegExp(r'^\s*\|?\s*:?-{3,}').hasMatch(lines[lineIndex + 1])) {
        final rows = <List<String>>[_tableCells(line)];
        lineIndex++;
        while (lineIndex + 1 < lines.length &&
            lines[lineIndex + 1].contains('|')) {
          lineIndex++;
          rows.add(_tableCells(lines[lineIndex]));
        }
        final columns = rows.first.length;
        children.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest),
            columns: [
              for (var column = 0; column < columns; column++)
                DataColumn(label: Text(rows.first[column])),
            ],
            rows: [
              for (final row in rows.skip(1))
                DataRow(cells: [
                  for (var column = 0; column < columns; column++)
                    DataCell(Text(column < row.length ? row[column] : '')),
                ]),
            ],
          ),
        ));
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final size = switch (heading.group(1)!.length) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          _ => theme.textTheme.titleMedium,
        };
        children.add(Text.rich(
            _inline(heading.group(2)!, size ?? bodyStyle, theme),
            style: size?.copyWith(fontWeight: FontWeight.w700)));
        continue;
      }
      final task = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s+(.*)$').firstMatch(line);
      if (task != null) {
        children
            .add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              task.group(1)!.trim().isEmpty
                  ? LucideIcons.square
                  : LucideIcons.squareCheck,
              size: 20,
              color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text.rich(_inline(task.group(2)!, bodyStyle, theme),
                  style: bodyStyle)),
        ]));
        continue;
      }
      final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        children
            .add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  '),
          Expanded(
              child: Text.rich(_inline(bullet.group(1)!, bodyStyle, theme),
                  style: bodyStyle)),
        ]));
        continue;
      }
      if (line.startsWith('> ')) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
              border: Border(
                  left:
                      BorderSide(color: theme.colorScheme.primary, width: 3))),
          child: Text.rich(_inline(line.substring(2), bodyStyle, theme),
              style: bodyStyle),
        ));
        continue;
      }
      final ordered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (ordered != null) {
        children
            .add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ordered.group(1)}.  '),
          Expanded(
              child: Text.rich(_inline(ordered.group(2)!, bodyStyle, theme),
                  style: bodyStyle)),
        ]));
        continue;
      }
      children
          .add(Text.rich(_inline(line, bodyStyle, theme), style: bodyStyle));
    }
    if (code.isNotEmpty) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SelectableText(code.join('\n'),
            style:
                theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
      ));
    }
    if (mathLines.isNotEmpty) {
      children.add(_mathBlock(theme, mathLines.join('\n')));
    }
    return ListView(
        padding: const EdgeInsets.only(bottom: 32), children: children);
  }

  TextSpan _inline(String source, TextStyle? base, ThemeData theme) {
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|(?<!\*)\*([^*]+)\*|`([^`]+)`|\[\[([^\]]+)\]\]|\[([^\]]+)\]\(([^)]+)\)|\$([^$]+)\$',
    );
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: source.substring(offset, match.start)));
      }
      final bold = match.group(1);
      final italic = match.group(2);
      final code = match.group(3);
      final note = match.group(4);
      final link = match.group(5);
      final math = match.group(7);
      spans.add(TextSpan(
        text: bold ?? italic ?? code ?? note ?? link ?? math,
        style: base?.copyWith(
          fontWeight: bold != null ? FontWeight.w700 : null,
          fontStyle: italic != null ? FontStyle.italic : null,
          fontFamily: code != null ? 'monospace' : null,
          backgroundColor: math != null
              ? theme.colorScheme.primary.withValues(alpha: .12)
              : null,
          color:
              (note != null || link != null) ? theme.colorScheme.primary : null,
          decoration: link != null ? TextDecoration.underline : null,
        ),
      ));
      offset = match.end;
    }
    if (offset < source.length) {
      spans.add(TextSpan(text: source.substring(offset)));
    }
    return TextSpan(style: base, children: spans);
  }

  List<String> _tableCells(String line) => line
      .trim()
      .replaceAll(RegExp(r'^\||\|$'), '')
      .split('|')
      .map((cell) => cell.trim())
      .toList();

  Widget _mathBlock(ThemeData theme, String expression) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SelectableText(expression,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'serif')),
      );
}

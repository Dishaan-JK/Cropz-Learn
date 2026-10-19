import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';

/// The saved learning workspace, rather than the host's source-code directory.
class WorkspaceFilesTree extends StatefulWidget {
  const WorkspaceFilesTree(
      {required this.notes,
      required this.canvases,
      required this.folders,
      required this.selectedNoteId,
      required this.selectedCanvasId,
      required this.selectedFolderId,
      required this.onNote,
      required this.onCanvas,
      required this.onFolder,
      required this.onCreateFolder,
      required this.onRenameFolder,
      required this.onDeleteFolder,
      super.key});
  final List<Note> notes;
  final List<LearningCanvas> canvases;
  final List<Folder> folders;
  final String? selectedNoteId, selectedCanvasId, selectedFolderId;
  final ValueChanged<Note> onNote;
  final ValueChanged<LearningCanvas> onCanvas;
  final ValueChanged<String?> onFolder;
  final ValueChanged<Folder?> onCreateFolder;
  final ValueChanged<Folder> onRenameFolder, onDeleteFolder;
  @override
  State<WorkspaceFilesTree> createState() => _WorkspaceFilesTreeState();
}

class _WorkspaceFilesTreeState extends State<WorkspaceFilesTree> {
  final _collapsed = <String>{};
  void _toggle(String key) => setState(() {
        if (!_collapsed.add(key)) _collapsed.remove(key);
      });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final byId = {for (final folder in widget.folders) folder.id: folder};
    final children = <String?, List<Folder>>{};
    final notes = <String?, List<Note>>{};
    for (final folder in widget.folders) {
      children
          .putIfAbsent(
              byId.containsKey(folder.parentId) ? folder.parentId : null,
              () => [])
          .add(folder);
    }
    for (final note in widget.notes) {
      notes
          .putIfAbsent(
              byId.containsKey(note.folderId) ? note.folderId : null, () => [])
          .add(note);
    }
    for (final group in children.values) {
      group
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    for (final group in notes.values) {
      group.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    void addNotes(List<Note> items, int depth) {
      for (final note in items) {
        rows.add(_FileRow(
            title: note.title,
            icon: LucideIcons.fileText,
            depth: depth,
            selected: widget.selectedNoteId == note.id,
            onTap: () => widget.onNote(note)));
      }
    }

    final visited = <String>{};
    void addFolder(Folder folder, int depth, bool visible) {
      if (!visited.add(folder.id)) return;
      final expanded = !_collapsed.contains('folder:${folder.id}');
      final nested = children[folder.id] ?? [];
      final files = notes[folder.id] ?? [];
      if (visible) {
        rows.add(_TreeBranch(
            title: folder.name,
            depth: depth,
            expanded: expanded,
            count: nested.length + files.length,
            selected: widget.selectedFolderId == folder.id,
            onToggle: () => _toggle('folder:${folder.id}'),
            onTap: () => widget.onFolder(folder.id),
            actions: PopupMenuButton<String>(
                tooltip: 'Actions for ${folder.name}',
                icon: const Icon(LucideIcons.ellipsis, size: 16),
                onSelected: (action) {
                  switch (action) {
                    case 'create':
                      widget.onCreateFolder(folder);
                    case 'rename':
                      widget.onRenameFolder(folder);
                    case 'delete':
                      widget.onDeleteFolder(folder);
                  }
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'create', child: Text('New subfolder')),
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ])));
      }
      for (final child in nested) {
        addFolder(child, depth + 1, visible && expanded);
      }
      if (visible && expanded) {
        addNotes(files, depth + 1);
        if (nested.isEmpty && files.isEmpty) {
          rows.add(_TreeHint('Empty folder', depth: depth + 1));
        }
      }
    }

    for (final folder in children[null] ?? <Folder>[]) {
      addFolder(folder, 0, true);
    }
    // Orphaned/cyclic legacy structures remain accessible without duplicating
    // descendants when a valid parent is collapsed.
    for (final folder in widget.folders) {
      if (!visited.contains(folder.id)) addFolder(folder, 0, true);
    }
    final unfiled = notes[null] ?? [];
    rows.add(_TreeBranch(
        title: 'Unfiled',
        depth: 0,
        count: unfiled.length,
        expanded: !_collapsed.contains('unfiled'),
        selected: widget.selectedFolderId == '__unfiled__',
        onToggle: () => _toggle('unfiled'),
        onTap: () => widget.onFolder('__unfiled__')));
    if (!_collapsed.contains('unfiled')) {
      addNotes(unfiled, 1);
      if (unfiled.isEmpty) {
        rows.add(const _TreeHint('No unfiled notes', depth: 1));
      }
    }
    final canvases = [...widget.canvases]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    rows.add(_TreeBranch(
        title: 'Canvases',
        depth: 0,
        count: canvases.length,
        expanded: !_collapsed.contains('canvases'),
        onToggle: () => _toggle('canvases'),
        onTap: () => _toggle('canvases')));
    if (!_collapsed.contains('canvases')) {
      for (final canvas in canvases) {
        final key = 'canvas:${canvas.id}';
        rows.add(_TreeBranch(
            title: canvas.title,
            icon: LucideIcons.layoutDashboard,
            depth: 1,
            count: canvas.noteIds.length,
            expanded: !_collapsed.contains(key),
            selected: widget.selectedCanvasId == canvas.id,
            onToggle: () => _toggle(key),
            onTap: () => widget.onCanvas(canvas)));
        if (!_collapsed.contains(key)) {
          final linked = {for (final n in widget.notes) n.id: n};
          addNotes([
            for (final id in canvas.noteIds)
              if (linked[id] case final note?) note
          ], 2);
          if (canvas.noteIds.isEmpty) {
            rows.add(const _TreeHint('No linked notes', depth: 2));
          }
        }
      }
      if (canvases.isEmpty) {
        rows.add(const _TreeHint('No canvases yet', depth: 1));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _TreeBranch extends StatelessWidget {
  const _TreeBranch(
      {required this.title,
      required this.depth,
      required this.count,
      required this.expanded,
      required this.onToggle,
      required this.onTap,
      this.selected = false,
      this.actions,
      this.icon = LucideIcons.folder});
  final String title;
  final int depth, count;
  final bool expanded, selected;
  final VoidCallback onToggle, onTap;
  final Widget? actions;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(left: depth.clamp(0, 4) * 12.0, right: 8),
      child: Row(children: [
        IconButton(
            tooltip: '${expanded ? 'Collapse' : 'Expand'} $title',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: onToggle,
            icon: Icon(
                expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 14)),
        Expanded(
            child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 18,
                horizontalTitleGap: 8,
                leading: Icon(icon, size: 16),
                selected: selected,
                title:
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: onTap)),
        if (actions != null)
          SizedBox(width: 32, child: actions)
        else
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('$count',
                  style: Theme.of(context).textTheme.labelSmall)),
      ]));
}

class _FileRow extends StatelessWidget {
  const _FileRow(
      {required this.title,
      required this.icon,
      required this.depth,
      required this.selected,
      required this.onTap});
  final String title;
  final IconData icon;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(left: 40 + depth.clamp(0, 4) * 12.0, right: 12),
      child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          minLeadingWidth: 16,
          horizontalTitleGap: 8,
          leading: Icon(icon, size: 15),
          selected: selected,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: onTap));
}

class _TreeHint extends StatelessWidget {
  const _TreeHint(this.text, {required this.depth});
  final String text;
  final int depth;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(44 + depth.clamp(0, 4) * 12.0, 6, 12, 10),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall));
}

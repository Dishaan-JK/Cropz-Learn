import 'settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import 'lumi_theme.dart';
import 'workspace_files_tree.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    required this.width,
    required this.notes,
    required this.canvases,
    required this.selectedCanvasId,
    required this.onSelectCanvas,
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
    required this.recentChats,
    required this.onOpenChat,
    super.key,
  });

  final double width;
  final List<Note> notes;
  final List<LearningCanvas> canvases;
  final String? selectedCanvasId;
  final ValueChanged<LearningCanvas> onSelectCanvas;
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
  final List<({String agentPath, String sessionId, String title})> recentChats;
  final ValueChanged<({String agentPath, String sessionId})> onOpenChat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recent = <({Note? note, LearningCanvas? canvas, DateTime created})>[
      for (final note in notes)
        (note: note, canvas: null, created: note.createdAt ?? note.updatedAt),
      for (final canvas in canvases)
        (
          note: null,
          canvas: canvas,
          created: canvas.createdAt ?? canvas.updatedAt
        ),
    ]..sort((a, b) => b.created.compareTo(a.created));
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).extension<LumiTokens>()!.surface,
        border:
            Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Material(
        color: Theme.of(context).extension<LumiTokens>()!.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lumi',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        AppSettingsScope.settingsOf(context)
                            .text('workspaceName'),
                        style: Theme.of(context).textTheme.labelSmall),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(LucideIcons.plus),
                label: const Text('New note'),
                style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14)),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  hintText: 'Search your notes',
                  isDense: true,
                ),
              ),
            ),
            Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  child: Text('WORKSPACE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1, color: colors.onSurfaceVariant))),
              _NavRow(
                  icon: LucideIcons.house,
                  label: 'Home',
                  selected: !searchMode && workspaceView == 'home',
                  onTap: () => onWorkspaceView('home')),
              _NavRow(
                  icon: LucideIcons.library,
                  label: 'Artifacts',
                  selected: !searchMode && workspaceView == 'artifacts',
                  onTap: () => onWorkspaceView('artifacts')),
              _NavRow(
                  icon: LucideIcons.layoutDashboard,
                  label: 'Canvases',
                  selected: workspaceView == 'canvas',
                  onTap: () => onWorkspaceView('canvas')),
              _NavRow(
                  icon: LucideIcons.network,
                  label: 'Knowledge graph',
                  selected: workspaceView == 'graph',
                  onTap: () => onWorkspaceView('graph')),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  child: Text('LATEST CHATS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1, color: colors.onSurfaceVariant))),
              if (recentChats.isEmpty)
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
                    child: Text('Your recent conversations will appear here.',
                        style: Theme.of(context).textTheme.bodySmall)),
              for (final chat in recentChats.take(
                  AppSettingsScope.settingsOf(context).number('recentLimit')))
                ListTile(
                  key: ValueKey('recent-chat:${chat.sessionId}'),
                  dense: true,
                  minLeadingWidth: 20,
                  leading: const Icon(LucideIcons.messageCircle, size: 17),
                  title: Text(chat.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => onOpenChat(
                      (agentPath: chat.agentPath, sessionId: chat.sessionId)),
                ),
              if (searchMode)
                const _NavRow(
                    icon: LucideIcons.search,
                    label: 'Search results',
                    selected: true),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  child: Text('RECENTLY CREATED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1, color: colors.onSurfaceVariant))),
              if (recent.isEmpty)
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                    child: Text('New notes and canvases will appear here.',
                        style: Theme.of(context).textTheme.bodySmall)),
              for (final item in recent.take(8))
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListTile(
                      key: ValueKey(item.note != null
                          ? 'recent:note:${item.note!.id}'
                          : 'recent:canvas:${item.canvas!.id}'),
                      dense: true,
                      minLeadingWidth: 20,
                      leading: Icon(
                          item.note != null
                              ? LucideIcons.fileText
                              : LucideIcons.layoutDashboard,
                          size: 17),
                      title: Text(item.note?.title ?? item.canvas!.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.note != null ? 'Note' : 'Canvas',
                          style: Theme.of(context).textTheme.labelSmall),
                      selected: item.note != null
                          ? selected?.id == item.note!.id
                          : selectedCanvasId == item.canvas!.id,
                      onTap: () => item.note != null
                          ? onSelect(item.note!)
                          : onSelectCanvas(item.canvas!),
                    )),
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
                        icon: const Icon(LucideIcons.folderPlus, size: 18)),
                  ])),
              WorkspaceFilesTree(
                  key: const ValueKey('workspace-files'),
                  notes: notes,
                  canvases: canvases,
                  folders: folders,
                  selectedNoteId: selected?.id,
                  selectedCanvasId: selectedCanvasId,
                  selectedFolderId: selectedFolderId,
                  onNote: onSelect,
                  onCanvas: onSelectCanvas,
                  onFolder: onSelectFolder,
                  onCreateFolder: onCreateFolder,
                  onRenameFolder: onRenameFolder,
                  onDeleteFolder: onDeleteFolder),
              const SizedBox(height: 20),
            ])),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            ListTile(
              leading: const Icon(LucideIcons.slidersHorizontal),
              title: const Text('Settings'),
              selected: workspaceView == 'settings',
              trailing: IconButton(
                tooltip: 'Open settings',
                onPressed: onSettings,
                icon: const Icon(LucideIcons.chevronRight),
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
      required this.canUndo,
      required this.canRedo,
      required this.onUndo,
      required this.onRedo,
      this.onMenu,
      this.viewTitle,
      super.key});
  final Note? note;
  final String? viewTitle;
  final String? savedLabel;
  final bool agentOpen;
  final VoidCallback onToggleAgent;
  final VoidCallback onDelete;
  final VoidCallback onCreate;
  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;
  final bool canUndo, canRedo;
  final VoidCallback onUndo, onRedo;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(children: [
        if (onMenu != null)
          IconButton(
              tooltip: 'Open navigation',
              onPressed: onMenu,
              icon: const Icon(LucideIcons.menu)),
        if (!compact) const Icon(LucideIcons.house, size: 18),
        const SizedBox(width: 8),
        if (!compact)
          Text('Workspace', style: Theme.of(context).textTheme.bodySmall),
        if (!compact) const Icon(LucideIcons.chevronRight, size: 18),
        Expanded(
            child: Text(viewTitle ?? note?.title ?? 'Learning workspace',
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
            icon: const Icon(LucideIcons.search)),
        IconButton(
            tooltip: 'New note',
            onPressed: onCreate,
            icon: const Icon(LucideIcons.plus)),
        IconButton(
            tooltip: 'Undo last saved workspace change',
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(LucideIcons.undo2)),
        IconButton(
            tooltip: 'Redo last undone workspace change',
            onPressed: canRedo ? onRedo : null,
            icon: const Icon(LucideIcons.redo2)),
        if (note != null)
          IconButton(
              tooltip: 'Delete note',
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2)),
        if (!compact)
          IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(LucideIcons.settings)),
        IconButton(
          tooltip: agentOpen ? 'Close Lumi Coach' : 'Open Lumi Coach',
          onPressed: onToggleAgent,
          icon: Icon(LucideIcons.sparkles,
              color: Theme.of(context).extension<LumiTokens>()!.aiAccent),
        ),
      ]),
    );
  }

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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';
import 'package:lumi_learning_app/ui/workspace_files_tree.dart';
import 'package:lumi_learning_app/ui/workspace_widgets.dart';

final old = DateTime(2026, 10, 10), recent = DateTime(2026, 10, 19);
final notes = [
  Note(
      id: 'n1',
      title: 'Root note',
      content: '',
      folderId: 'f1',
      createdAt: old,
      updatedAt: recent),
  Note(
      id: 'n2',
      title: 'Nested note',
      content: '',
      folderId: 'f2',
      createdAt: recent,
      updatedAt: recent),
  Note(id: 'n3', title: 'Loose note', content: '', updatedAt: old),
];
final canvases = [
  LearningCanvas(
      id: 'c1',
      title: 'New canvas',
      description: '',
      noteIds: ['n1'],
      createdAt: recent.add(const Duration(hours: 1)),
      updatedAt: recent)
];
const folders = [
  Folder(id: 'f1', name: 'Biology'),
  Folder(id: 'f2', name: 'Cells', parentId: 'f1')
];

void main() {
  testWidgets(
      'tree nests notes, unfiled data and canvas-linked notes; collapsing hides descendants',
      (tester) async {
    tester.view.physicalSize = const Size(264, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        theme: LumiTheme.light(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: WorkspaceFilesTree(
                    notes: notes,
                    canvases: canvases,
                    folders: folders,
                    selectedNoteId: null,
                    selectedCanvasId: null,
                    selectedFolderId: null,
                    onNote: (n) => opened = n.id,
                    onCanvas: (c) => opened = c.id,
                    onFolder: (_) {},
                    onCreateFolder: (_) {},
                    onRenameFolder: (_) {},
                    onDeleteFolder: (_) {})))));
    expect(find.text('Nested note'), findsOneWidget);
    expect(find.text('Root note'), findsNWidgets(2));
    expect(find.text('Loose note'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse Biology'));
    await tester.pump();
    expect(find.text('Cells'), findsNothing);
    expect(find.text('Nested note'), findsNothing);
    expect(find.text('Root note'), findsOneWidget);
    await tester.tap(find.text('New canvas'));
    expect(opened, 'c1');
    await tester.tap(find.text('Root note'));
    expect(opened, 'n1');
    await tester.tap(find.byTooltip('Expand Biology'));
    await tester.pump();
    await tester.tap(find.text('Nested note'));
    expect(opened, 'n2');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sidebar removes All notes and sorts mixed recent items by creation',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        theme: LumiTheme.light(),
        home: Scaffold(
            body: Align(
                alignment: Alignment.centerLeft,
                child: WorkspaceSidebar(
                    width: 264,
                    notes: notes,
                    canvases: canvases,
                    folders: folders,
                    selectedCanvasId: null,
                    onSelectCanvas: (c) => opened = c.id,
                    selectedFolderId: 'f1',
                    onSelectFolder: (_) {},
                    onCreateFolder: (_) {},
                    onDeleteFolder: (_) {},
                    onRenameFolder: (_) {},
                    selected: null,
                    searchMode: false,
                    onCreate: () {},
                    onSelect: (n) => opened = n.id,
                    onSearch: (_) {},
                    onToggleTheme: () {},
                    onSettings: () {},
                    workspaceView: 'artifacts',
                    recentChats: const [
                      (
                        agentPath: '/api/assistant',
                        sessionId: 'chat-1',
                        title: 'Cell structure'
                      )
                    ],
                    onOpenChat: (_) {},
                    onWorkspaceView: (_) {})))));
    expect(find.text('All notes'), findsNothing);
    expect(find.text('LEARNING AGENTS'), findsNothing);
    expect(find.text('LATEST CHATS'), findsOneWidget);
    expect(find.text('Cell structure'), findsOneWidget);
    final canvas = find.byKey(const ValueKey('recent:canvas:c1'));
    final newestNote = find.byKey(const ValueKey('recent:note:n2'));
    final editedOldNote = find.byKey(const ValueKey('recent:note:n1'));
    expect(tester.getTopLeft(canvas).dy,
        lessThan(tester.getTopLeft(newestNote).dy));
    expect(tester.getTopLeft(newestNote).dy,
        lessThan(tester.getTopLeft(editedOldNote).dy));
    await tester.tap(canvas);
    expect(opened, 'c1');
    await tester.tap(newestNote);
    expect(opened, 'n2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar exposes enabled undo and redo actions', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var undoCount = 0;
    var redoCount = 0;

    await tester.pumpWidget(MaterialApp(
      theme: LumiTheme.light(),
      home: Scaffold(
        body: WorkspaceTopBar(
          note: null,
          savedLabel: null,
          agentOpen: false,
          onToggleAgent: () {},
          onDelete: () {},
          onCreate: () {},
          onSearch: (_) {},
          onSettings: () {},
          canUndo: false,
          canRedo: false,
          onUndo: () => undoCount++,
          onRedo: () => redoCount++,
        ),
      ),
    ));

    final undo = find.byIcon(LucideIcons.undo2);
    final redo = find.byIcon(LucideIcons.redo2);
    final undoButton =
        find.ancestor(of: undo, matching: find.byType(IconButton));
    final redoButton =
        find.ancestor(of: redo, matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(undoButton).onPressed, isNull);
    expect(tester.widget<IconButton>(redoButton).onPressed, isNull);

    await tester.pumpWidget(MaterialApp(
      theme: LumiTheme.light(),
      home: Scaffold(
        body: WorkspaceTopBar(
          note: null,
          savedLabel: null,
          agentOpen: false,
          onToggleAgent: () {},
          onDelete: () {},
          onCreate: () {},
          onSearch: (_) {},
          onSettings: () {},
          canUndo: true,
          canRedo: true,
          onUndo: () => undoCount++,
          onRedo: () => redoCount++,
        ),
      ),
    ));
    await tester.tap(undo);
    await tester.tap(redo);
    expect(undoCount, 1);
    expect(redoCount, 1);
  });
}

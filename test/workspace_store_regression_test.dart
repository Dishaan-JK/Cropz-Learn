// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/backend/workspace_folders.dart';
import 'package:lumi_learning_app/backend/workspace_notes.dart';

void main() {
  late Directory sandbox;
  late WorkspaceNotes notes;
  late WorkspaceFolders folders;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lumi-regression-');
    notes = WorkspaceNotes(File('${sandbox.path}/notes.json'));
    folders = WorkspaceFolders(File('${sandbox.path}/folders.json'));
    await notes.load();
    await folders.load();
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('note create, update, search and delete survive reload', () async {
    final first = await notes.save(
      title: 'Cellular Energy',
      content: 'Mitochondria convert glucose into usable energy.',
    );
    final updated = await notes.save(
      id: first.id,
      title: first.title,
      content: 'Mitochondria convert glucose into ATP.',
    );

    expect(updated.createdAt, first.createdAt);
    expect(notes.search('ATP').single.id, first.id);
    expect(notes.search('GLUCOSE').single.id, first.id);

    final reloaded = WorkspaceNotes(File('${sandbox.path}/notes.json'));
    await reloaded.load();
    expect(reloaded.get(first.id)?.content, contains('ATP'));
    expect(await reloaded.delete(first.id), isTrue);
    expect(await reloaded.delete(first.id), isFalse);

    final afterDelete = WorkspaceNotes(File('${sandbox.path}/notes.json'));
    await afterDelete.load();
    expect(afterDelete.list(), isEmpty);
  });

  test('knowledge links only connect existing notes and omit self links',
      () async {
    final alpha = await notes.save(
      title: 'Alpha',
      content: 'See [[Beta]], [[Missing]], and [[Alpha]].',
    );
    final beta = await notes.save(title: 'Beta', content: 'Related to Alpha.');

    expect(notes.links(), [
      {'from': alpha.id, 'to': beta.id}
    ]);
  });

  test('folder names are required and deleting parent safely promotes children',
      () async {
    expect(() => folders.save(name: '  '), throwsFormatException);
    final parent = await folders.save(name: 'Biology');
    final child = await folders.save(name: 'Cells', parentId: parent.id);
    await expectLater(
      folders.save(id: parent.id, name: 'Biology', parentId: child.id),
      throwsFormatException,
    );

    expect(await folders.delete(parent.id), isTrue);
    final reloaded = WorkspaceFolders(File('${sandbox.path}/folders.json'));
    await reloaded.load();
    expect(reloaded.get(child.id)?.parentId, isNull);
    expect(reloaded.get(child.id)?.name, 'Cells');
  });
}

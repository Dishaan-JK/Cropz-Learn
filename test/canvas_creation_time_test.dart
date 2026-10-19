import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/backend/workspace_canvases.dart';

void main() {
  test('canvas creation time survives layout edits, detach and disk reload',
      () async {
    final dir = await Directory.systemTemp.createTemp('lumi-canvas-created-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/canvases.json');
    final store = WorkspaceCanvases(file);
    final canvas = await store
        .create(title: 'Cells', noteIds: ['n1'], existingNoteIds: {'n1'});
    await store
        .updatePositions(canvas.id, {'n1': const CanvasPosition(10, 20)});
    await store.detachNote('n1');
    final restored = WorkspaceCanvases(file);
    await restored.load();
    expect(restored.list().single.createdAt, canvas.createdAt);
    expect(restored.list().single.noteIds, isEmpty);
  });

  test('interactive quiz survives reload, hides its key and is graded',
      () async {
    final dir = await Directory.systemTemp.createTemp('lumi-canvas-quiz-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/canvases.json');
    final store = WorkspaceCanvases(file);
    final canvas = await store.create(
      title: 'World Capitals Practice',
      noteIds: const [],
      existingNoteIds: const {},
    );
    final withQuiz = await store.addQuiz(
      canvas.id,
      title: 'Capital Cities',
      description: 'Choose the correct capital.',
      questions: [
        {
          'prompt': 'What is the capital of France?',
          'options': ['Paris', 'Rome', 'Madrid', 'Lisbon'],
          'answerIndex': 0,
          'explanation': 'Paris is the capital of France.',
        },
      ],
    );
    expect(withQuiz.toJson()['quizzes'].toString(),
        isNot(contains('answerIndex')));
    final restored = WorkspaceCanvases(file);
    await restored.load();
    expect(restored.list().single.title, 'World Capitals Practice');
    expect(
        restored
            .gradeQuiz(canvas.id, withQuiz.quizzes.single['id'] as String, [0]),
        {
          'title': 'Capital Cities',
          'topic': 'World Capitals Practice',
          'score': 1,
          'total': 1,
          'results': [
            {
              'correct': true,
              'answerIndex': 0,
              'explanation': 'Paris is the capital of France.'
            },
          ],
        });
  });
}

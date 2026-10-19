import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/experimental.dart';
import 'package:lumi_learning_app/backend/academic_artifacts.dart';
import 'package:lumi_learning_app/backend/agent_sessions.dart';

Map<String, dynamic> snapshot(
        {String status = 'completed',
        String text = '# Cells quiz\nWhat is a cell?'}) =>
    {
      'snapshotId': 'snapshot-one',
      'sessionId': 'session-one',
      'createdAt': '2026-10-19T08:00:00.000Z',
      'status': status,
      'state': {
        'sessionId': 'session-one',
        'messages': [
          {
            'role': 'system',
            'content': [
              {'text': 'Private configuration'}
            ]
          },
          {
            'role': 'user',
            'content': [
              {'text': 'Please create a quiz on cells'}
            ]
          },
          {
            'role': 'model',
            'content': [
              {
                'text': 'Internal planning',
                'toolRequest': {'name': 'lookup'}
              }
            ]
          },
          {
            'role': 'tool',
            'content': [
              {'text': 'Internal tool result'}
            ]
          },
          {
            'role': 'model',
            'content': [
              {'text': text}
            ]
          },
        ]
      },
    };

void main() {
  late Directory directory;
  late AcademicArtifacts artifacts;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lumi-artifacts-test-');
    artifacts = AcademicArtifacts(File('${directory.path}/artifacts.json'));
    await artifacts.load();
  });
  tearDown(() => directory.delete(recursive: true));

  test('captures final academic text once and excludes private/tool messages',
      () async {
    await artifacts.captureSnapshot(snapshot(status: 'pending'));
    expect(artifacts.list(), isEmpty);
    await artifacts.captureSnapshot(snapshot());
    await artifacts.captureSnapshot(snapshot());
    expect(artifacts.list(), hasLength(1));
    expect(artifacts.list().single['kind'], 'Quizzes');
    expect(artifacts.list().single['content'], '# Cells quiz\nWhat is a cell?');
    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    expect(restored.list(), artifacts.list());
  });

  test('keeps distinct regenerated answers and original capture dates',
      () async {
    await artifacts.captureSnapshot(snapshot());
    final later = snapshot(text: '# Cells quiz\nExplain the nucleus.');
    later['createdAt'] = '2026-10-20T08:00:00.000Z';
    await artifacts.captureSnapshot(later);
    await artifacts.captureSnapshot(
        {...snapshot(), 'createdAt': '2026-10-21T08:00:00.000Z'});
    expect(artifacts.list(), hasLength(2));
    expect(artifacts.list().last['updatedAt'], '2026-10-19T08:00:00.000Z');
  });

  test('saves revision exams as reusable library artifacts', () async {
    final saved = await artifacts.create(
      kind: 'Revision exams',
      title: 'Term 1 revision exam',
      content: '## Instructions\nAnswer all questions.\n\n1. Explain cells.',
      source: 'Lumi Tester',
    );
    expect(saved['kind'], 'Revision exams');
    expect(artifacts.list().single['content'], contains('Explain cells'));

    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    expect(restored.list().single['title'], 'Term 1 revision exam');
  });

  test('rejects unsupported or empty generated artifact content', () async {
    await expectLater(
      artifacts.create(
        kind: 'Unlisted kind',
        title: 'Paper',
        content: 'Question',
        source: 'Lumi Tester',
      ),
      throwsFormatException,
    );
    await expectLater(
      artifacts.create(
        kind: 'Quizzes',
        title: 'Quiz',
        content: '  ',
        source: 'Lumi Tester',
      ),
      throwsFormatException,
    );
  });

  test(
      'interactive quiz survives reload, hides keys and grades repeated attempts',
      () async {
    final item = await artifacts.create(
      kind: 'Quizzes',
      title: 'Cells checkpoint',
      content: 'Which organelle releases energy?',
      source: 'Lumi Tester',
      learningObject: {
        'type': 'quiz',
        'questions': [
          {
            'prompt': 'Which organelle releases energy?',
            'options': ['Mitochondrion', 'Nucleus', 'Membrane', 'Ribosome'],
            'answerIndex': 0,
            'explanation': 'Mitochondria produce ATP.',
          }
        ],
      },
    );
    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    final public = jsonEncode(restored.publicList());
    expect(public, isNot(contains('answerIndex')));
    expect(public, isNot(contains('Mitochondria produce ATP.')));
    final wrong = await restored.submitQuiz(item['id'] as String, [2]);
    expect(wrong['score'], 0);
    expect((wrong['feedback'] as List).single['explanation'],
        'Mitochondria produce ATP.');
    expect((await restored.submitQuiz(item['id'] as String, [0]))['score'], 1);
    for (final answers in [
      [],
      [4],
      [-1],
      [0.0],
      ['0'],
      null
    ]) {
      await expectLater(restored.submitQuiz(item['id'] as String, answers),
          throwsFormatException);
    }
    await expectLater(
        restored.submitQuiz('missing', [0]), throwsFormatException);
  });

  test('structured flashcards persist independently of conversations',
      () async {
    await artifacts.create(
        kind: 'Flashcards',
        title: 'Cells recall',
        content: 'Front: ATP\nBack: Energy carrier',
        source: 'Lumi Teacher',
        learningObject: {
          'type': 'flashcards',
          'cards': [
            {'front': 'ATP', 'back': 'Energy carrier'}
          ]
        });
    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    final object = restored.publicList().single['learningObject'] as Map;
    expect((object['cards'] as List).single['back'], 'Energy carrier');
  });

  test('malformed interactive objects cannot be persisted', () async {
    for (final object in <Map<String, Object?>>[
      {'type': 'quiz', 'questions': []},
      {
        'type': 'quiz',
        'questions': [
          {
            'prompt': 'Question',
            'options': ['A'],
            'answerIndex': 0
          }
        ]
      },
      {
        'type': 'flashcards',
        'cards': [
          {'front': 'Question', 'back': ''}
        ]
      },
    ]) {
      await expectLater(
          artifacts.create(
              kind: object['type'] == 'quiz' ? 'Quizzes' : 'Flashcards',
              title: 'Invalid',
              content: 'Body',
              source: 'Test',
              learningObject: object),
          throwsFormatException);
    }
    expect(artifacts.list(), isEmpty);
  });

  test('backend session persistence archives before conversation deletion',
      () async {
    final sessions = Directory('${directory.path}/sessions');
    final store = ArchivingSessionStore(sessions.path, artifacts);
    await store.saveSnapshot(null, (_) => SessionSnapshot.fromJson(snapshot()));
    expect(artifacts.list(), hasLength(1));
    await AgentSessions(sessions).delete('session-one');
    expect(await store.getSnapshot(sessionId: 'session-one'), isNull);
    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    expect(restored.list(), hasLength(1));
  });

  test('backfills available history and skips damaged JSON', () async {
    final history = Directory('${directory.path}/history');
    await history.create();
    await File('${history.path}/old.json')
        .writeAsString(jsonEncode(snapshot()));
    await File('${history.path}/broken.json').writeAsString('{');
    await artifacts.backfill(history);
    await artifacts.backfill(history);
    expect(artifacts.list(), hasLength(1));
  });

  test('serializes concurrent writes without losing objects', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++)
        artifacts.collect([
          {
            'id': 'note:$i',
            'kind': 'Notes',
            'title': 'Note $i',
            'content': 'Body',
            'source': 'Workspace',
            'sourceId': '$i',
            'updatedAt': '2026-10-19T08:00:00Z',
          }
        ])
    ]);
    final restored = AcademicArtifacts(artifacts.file);
    await restored.load();
    expect(restored.list(), hasLength(20));
  });
}

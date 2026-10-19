import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/backend/learning_record.dart';

void main() {
  late Directory directory;
  late LearningRecord record;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lumi-learning-record-');
    record = LearningRecord(File('${directory.path}/record.json'));
    await record.load();
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('review intervals adapt after repeated strong results', () async {
    final first = await record.record(
      agent: 'tester',
      kind: 'quiz',
      topic: 'Photosynthesis',
      evidence: 'Correctly identified the products.',
      score: .9,
    );
    final second = await record.record(
      agent: 'tester',
      kind: 'quiz',
      topic: 'photosynthesis',
      evidence: 'Explained the role of sunlight accurately.',
      score: .95,
    );

    final firstDays = DateTime.parse(first['reviewAt'] as String)
        .difference(DateTime.parse(first['recordedAt'] as String))
        .inDays;
    final secondDays = DateTime.parse(second['reviewAt'] as String)
        .difference(DateTime.parse(second['recordedAt'] as String))
        .inDays;
    expect(firstDays, 7);
    expect(secondDays, 14);
  });

  test('groups topic casing and reports due topics once', () async {
    await record.record(
      agent: 'tester',
      kind: 'quiz',
      topic: 'Fractions',
      evidence: 'Confused numerator and denominator.',
      score: .4,
      misconception: 'Swapped numerator and denominator',
    );
    await record.record(
      agent: 'reviewer',
      kind: 'review',
      topic: 'fractions',
      evidence: 'Corrected the numerator after a recall prompt.',
      score: .6,
    );

    final due = record.dueReviews(
        now: DateTime.now().toUtc().add(
              const Duration(days: 4),
            ));
    expect(due, hasLength(1));
    expect(due.single['topic'], 'fractions');
  });

  test('summarizes score trends and repeated misconceptions', () async {
    for (var i = 0; i < 4; i++) {
      await record.record(
        agent: 'tester',
        kind: 'quiz',
        topic: 'Electric circuits',
        evidence: 'Answered circuit question $i.',
        score: .2,
        misconception: 'Current is used up by a bulb',
      );
    }
    for (var i = 0; i < 3; i++) {
      await record.record(
        agent: 'reviewer',
        kind: 'review',
        topic: 'Electric circuits',
        evidence: 'Correctly explained a closed circuit.',
        score: .9,
      );
    }

    final pattern = record.patterns().single;
    expect(pattern['attempts'], 7);
    expect(pattern['trend'], 'improving');
    expect(pattern['recurringMisconceptions'], isNotEmpty);
  });

  test('persists evidence and rejects unsupported agent or score values',
      () async {
    await expectLater(
      record.record(
        agent: 'unknown',
        kind: 'test',
        topic: 'Algebra',
        evidence: 'Attempted a question.',
      ),
      throwsFormatException,
    );
    await expectLater(
      record.record(
        agent: 'tester',
        kind: 'test',
        topic: 'Algebra',
        evidence: 'Attempted a question.',
        score: 1.1,
      ),
      throwsFormatException,
    );
    await record.record(
      agent: 'tester',
      kind: 'test',
      topic: 'Algebra',
      evidence: 'Correctly isolated the variable.',
      score: .8,
    );

    final reloaded = LearningRecord(File('${directory.path}/record.json'));
    await reloaded.load();
    expect(reloaded.events, hasLength(1));
    expect(reloaded.patterns().single['topic'], 'Algebra');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/artifacts_page.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

void main() {
  for (final width in [390.0, 1180.0]) {
    for (final dark in [false, true]) {
      for (final quiz in [false, true]) {
        testWidgets('saved ${quiz ? 'quiz' : 'deck'} review $width dark=$dark',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var attempts = 0;
          final artifact = AcademicArtifact(
            id: 'generated:one',
            kind: quiz ? 'Quizzes' : 'Flashcards',
            title: 'Cells practice',
            content: 'Cell recall',
            source: 'Lumi',
            sourceId: 'generated',
            updatedAt: DateTime(2026, 10, 19),
            learningObject: quiz
                ? {
                    'type': 'quiz',
                    'questions': [
                      {
                        'prompt': 'Energy carrier?',
                        'options': ['ATP', 'DNA', 'RNA', 'Water'],
                      }
                    ],
                  }
                : {
                    'type': 'flashcards',
                    'cards': [
                      {'front': 'ATP?', 'back': 'Energy carrier'},
                      {'front': 'DNA?', 'back': 'Genetic material'},
                    ],
                  },
          );
          await tester.pumpWidget(MaterialApp(
            theme: dark ? LumiTheme.dark() : LumiTheme.light(),
            home: Scaffold(
                body: ArtifactsPage(
              load: () async => [artifact],
              revision: 0,
              onCreate: () {},
              onCoach: () {},
              hasSource: (_) => false,
              onOpenSource: (_) {},
              submitQuiz: (id, answers) async {
                expect(id, artifact.id);
                expect(answers, [0]);
                if (attempts++ == 0) throw Exception('offline');
                return {
                  'score': 1,
                  'total': 1,
                  'feedback': [
                    {
                      'correct': true,
                      'answerIndex': 0,
                      'explanation': 'ATP supplies energy.'
                    },
                  ]
                };
              },
            )),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cells practice'));
          await tester.pumpAndSettle();
          if (quiz) {
            expect(
                tester
                    .widget<FilledButton>(
                        find.widgetWithText(FilledButton, 'Check answers'))
                    .onPressed,
                isNull);
            expect(find.textContaining('ATP supplies energy.'), findsNothing);
            await tester.tap(find.text('A. ATP'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Check answers'));
            await tester.pumpAndSettle();
            expect(find.textContaining('could not be checked'), findsOneWidget);
            await tester.tap(find.text('Check answers'));
            await tester.pumpAndSettle();
            expect(find.text('Score: 1 / 1'), findsOneWidget);
            expect(find.textContaining('ATP supplies energy.'), findsOneWidget);
            await tester.tap(find.text('Try again'));
            await tester.pumpAndSettle();
            expect(find.text('0 of 1 answered'), findsOneWidget);
          } else {
            expect(find.text('Energy carrier'), findsNothing);
            await tester.tap(find.text('Reveal answer'));
            await tester.pumpAndSettle();
            expect(find.text('Energy carrier'), findsOneWidget);
            await tester.tap(find.text('Next card'));
            await tester.pumpAndSettle();
            expect(find.text('DNA?'), findsOneWidget);
            expect(find.text('Energy carrier'), findsNothing);
            expect(find.text('Genetic material'), findsNothing);
            await tester.tap(find.text('Reveal answer'));
            await tester.pumpAndSettle();
            expect(find.text('Genetic material'), findsOneWidget);
            await tester.tap(find.text('Start over'));
            await tester.pumpAndSettle();
            expect(find.text('Card 1 of 2'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close artifact'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cells practice'));
          await tester.pumpAndSettle();
          expect(find.text(quiz ? '0 of 1 answered' : 'Card 1 of 2'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

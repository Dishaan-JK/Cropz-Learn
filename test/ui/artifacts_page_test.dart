import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/artifacts_page.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

final items = [
  AcademicArtifact(
      id: 'n1',
      kind: 'Notes',
      title: 'Cell biology',
      content: 'Mitochondria and energy',
      source: 'Workspace',
      sourceId: 'n1',
      updatedAt: DateTime(2026, 10, 19)),
  AcademicArtifact(
      id: 'q1',
      kind: 'Quizzes',
      title: 'Energy checkpoint',
      content: '# Question\nExplain ATP synthesis.',
      source: 'Lumi Coach',
      sourceId: 's1',
      updatedAt: DateTime(2026, 10, 18)),
];

Widget page(
        {Future<List<AcademicArtifact>> Function()? load, bool dark = false}) =>
    MaterialApp(
        theme: dark ? LumiTheme.dark() : LumiTheme.light(),
        home: Scaffold(
            body: ArtifactsPage(
          load: load ?? () async => items,
          revision: 0,
          onCreate: () {},
          onCoach: () {},
          hasSource: (a) => a.kind == 'Notes',
          onOpenSource: (_) {},
        )));

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [390.0, 700.0, 1180.0]) {
    for (final dark in [false, true]) {
      testWidgets('library and reader fit width $width dark=$dark',
          (tester) async {
        viewport(tester, Size(width, 844));
        await tester.pumpWidget(page(dark: dark));
        await tester.pumpAndSettle();
        expect(find.text('Your learning, collected.'), findsOneWidget);
        await tester.tap(find.text('Cell biology'));
        await tester.pumpAndSettle();
        expect(find.text('Open in workspace'), findsOneWidget);
        expect(find.text('Copy text'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close artifact'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('List view'));
        await tester.pumpAndSettle();
        expect(find.text('Energy checkpoint'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('search filters full content and clears empty results',
      (tester) async {
    viewport(tester, const Size(1180, 844));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ATP');
    await tester.pumpAndSettle();
    expect(find.text('Cell biology'), findsNothing);
    expect(find.text('Energy checkpoint'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not present');
    await tester.pumpAndSettle();
    expect(find.text('No matching artifacts'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Cell biology'), findsOneWidget);
  });
  testWidgets('failed load retries and empty library has creation actions',
      (tester) async {
    viewport(tester, const Size(1180, 1000));
    var calls = 0;
    await tester.pumpWidget(page(load: () async {
      if (calls++ == 0) throw Exception('offline');
      return [];
    }));
    await tester.pumpAndSettle();
    expect(find.text('Let’s reconnect your library'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Create a note'), findsOneWidget);
    expect(find.text('Ask Lumi Coach'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/ui/app.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Lumi responsive navigation', () {
    testWidgets('shows the full workspace sidebar on wide screens',
        (tester) async {
      setViewport(tester, const Size(1440, 1000));
      await tester.pumpWidget(const LumiWebApp());
      await tester.pump();
      expect(find.text('All notes'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('RECENTLY CREATED'), 160,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('RECENTLY CREATED'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('FOLDERS'), 160,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('FOLDERS'), findsOneWidget);
    });

    testWidgets('shows the compact navigation rail at medium width',
        (tester) async {
      setViewport(tester, const Size(1024, 768));
      await tester.pumpWidget(const LumiWebApp());
      await tester.pump();
      expect(find.byTooltip('Open workspace navigation'), findsOneWidget);
      expect(find.text('All notes'), findsNothing);
    });

    testWidgets('shows a drawer entry point on narrow screens', (tester) async {
      setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(const LumiWebApp());
      await tester.pump();
      expect(find.byTooltip('Open navigation'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.text('All notes'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('RECENTLY CREATED'), 160,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('RECENTLY CREATED'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('opens and closes Coach as a medium-width overlay',
        (tester) async {
      setViewport(tester, const Size(1024, 768));
      await tester.pumpWidget(const LumiWebApp());
      await tester.pump();
      await tester.tap(find.byTooltip('Open Lumi Coach'));
      await tester.pump();
      expect(find.text('Lumi Coach'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Coach panel'));
      await tester.pump();
      expect(find.text('Lumi Coach'), findsNothing);
    });

    testWidgets('settings exposes all eight sections', (tester) async {
      setViewport(tester, const Size(1440, 1000));
      await tester.pumpWidget(const LumiWebApp());
      await tester.pump();
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (final label in [
        'General',
        'Appearance',
        'AI & models',
        'Learning & coach',
        'Workspace & editor',
        'Artifacts & storage',
        'Privacy & data',
        'About & diagnostics'
      ]) {
        expect(find.text(label), findsWidgets);
      }
    });
  });

  testWidgets('warm light and dark themes share the selected accent',
      (tester) async {
    final light = LumiTheme.light(accent: LumiAccent.maroon);
    final dark = LumiTheme.dark(accent: LumiAccent.maroon);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF4F1E8));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF191C19));
    expect(light.colorScheme.primary, LumiAccent.maroon.lightColor);
    expect(dark.colorScheme.primary, LumiAccent.maroon.darkColor);
    expect(light.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    expect(light.textTheme.headlineSmall?.fontFamily, 'Lora');
  });
}

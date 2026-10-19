import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/data/app_settings.dart';
import 'package:lumi_learning_app/ui/settings_controller.dart';
import 'package:lumi_learning_app/ui/settings_page.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

void main() {
  Future<SettingsController> mount(WidgetTester tester,
      {double width = 1440,
      bool failSave = false,
      Future<void>? saveGate}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final values = Map<String, dynamic>.of(AppSettings.defaults);
    final client = MockClient((request) async {
      if (request.url.path == '/api/application-settings') {
        if (request.method == 'PUT') {
          if (saveGate != null) await saveGate;
          if (failSave) return http.Response('{"error":"Disk full"}', 500);
          values.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(jsonEncode(values), 200);
      }
      if (request.url.path == '/api/profile') {
        return http.Response('{"preferences":[]}', 200);
      }
      return http.Response(
          '{"service":"Online","provider":"ollama","model":"test","storageBytes":128,"notes":2,"canvases":1,"folders":1,"artifacts":3}',
          200);
    });
    final api = LumiApi(client: client);
    final controller = SettingsController(api: api);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(AppSettingsScope(
        controller: controller,
        child: MaterialApp(
            theme: LumiTheme.light(),
            home: Scaffold(
                body: SettingsPage(
                    isDark: false,
                    accent: LumiAccent.sage,
                    onToggleTheme: () {},
                    api: api)))));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('save button reflects idle, pending, saved and edited states',
      (tester) async {
    final gate = Completer<void>();
    final controller = await mount(tester, saveGate: gate.future);
    FilledButton button(String label) =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
    expect(button('Save changes').onPressed, isNull);
    await tester.enterText(find.byType(TextFormField).first, 'Ada');
    await tester.pump();
    expect(button('Save changes').onPressed, isNotNull);
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(button('Saving…').onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(button('Saved').onPressed, isNull);
    expect(find.text('All changes saved'), findsOneWidget);
    expect(controller.pending, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'Grace');
    await tester.pump();
    expect(button('Save changes').onPressed, isNotNull);
    expect(find.text('1 unsaved change'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(button('Save changes').onPressed, isNull);
    expect(find.text('No unsaved changes'), findsOneWidget);
  });

  testWidgets('new edits during saving remain unsaved and can be saved again',
      (tester) async {
    final gate = Completer<void>();
    final controller = await mount(tester, saveGate: gate.future);
    await tester.enterText(find.byType(TextFormField).first, 'Ada');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Grace');
    gate.complete();
    await tester.pumpAndSettle();
    expect(controller.settings.text('displayName'), 'Ada');
    expect(controller.pending['displayName'], 'Grace');
    expect(find.text('Saved'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNotNull);
  });

  testWidgets('eight sections, editable text, persistence and discard',
      (tester) async {
    final controller = await mount(tester);
    for (final section in settingsSections) {
      expect(find.text(section.title), findsWidgets);
    }
    await tester.enterText(find.byType(TextFormField).first, 'Ada Lovelace');
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.settings.text('displayName'), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).first, 'Temporary');
    await tester.pump();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Temporary'), findsNothing);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Reading comfort'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
        'Canvas colour controls save, validate, preview and discard at $width',
        (tester) async {
      final controller = await mount(tester, width: width);
      if (width < 820) {
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appearance').last);
      } else {
        await tester.tap(find.text('Appearance'));
      }
      await tester.pumpAndSettle();
      final background =
          find.widgetWithText(TextFormField, 'Canvas background');
      await tester.ensureVisible(background);
      await tester.pumpAndSettle();
      await tester.enterText(background, '#DDEEFF');
      await tester.pumpAndSettle();
      expect(controller.pending['canvasBackgroundLight'], '#DDEEFF');
      expect(controller.settings.text('canvasBackgroundLight'), '#F4F1E8');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(controller.settings.text('canvasBackgroundLight'), '#DDEEFF');
      await tester.ensureVisible(background);
      await tester.enterText(background, '#GGGGGG');
      await tester.pumpAndSettle();
      expect(find.text('Use a colour such as #F4F1E8.'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(controller.settings.text('canvasBackgroundLight'), '#DDEEFF');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(controller.pending, isEmpty);
      expect(find.text('#DDEEFF'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Choose canvas background'));
      await tester.tap(find.byTooltip('Choose canvas background'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pale sage'));
      await tester.pumpAndSettle();
      expect(controller.pending['canvasBackgroundLight'], '#EAF0E9');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed save keeps staged changes and reports backend error',
      (tester) async {
    final controller = await mount(tester, failSave: true);
    await tester.enterText(find.byType(TextFormField).first, 'Ada');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Disk full'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNotNull);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('1 unsaved change'), findsOneWidget);
    expect(controller.settings.text('displayName'), '');
  });
  testWidgets('mobile navigation and settings search fit without overflow',
      (tester) async {
    await mount(tester, width: 390);
    await tester.enterText(find.byType(TextField).first, 'spelling');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspace & editor').last);
    await tester.pumpAndSettle();
    expect(find.text('Writing experience'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

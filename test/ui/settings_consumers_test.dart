import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/note_editor.dart';
import 'package:lumi_learning_app/ui/settings_controller.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

void main() {
  Future<SettingsController> settings(Map<String, dynamic> values) async {
    final controller = SettingsController(
        api: LumiApi(
            client: MockClient(
                (_) async => http.Response(jsonEncode(values), 200))));
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  Widget editor(SettingsController controller,
          Future<bool> Function(Note, String, String) onSave) =>
      AppSettingsScope(
          controller: controller,
          child: MaterialApp(
              theme: LumiTheme.light(),
              home: Scaffold(
                  body: NoteEditor(
                note: Note(
                    id: 'test-note',
                    title: 'Biology',
                    content: '# Cell structure',
                    updatedAt: DateTime(2026)),
                folders: const [],
                onSave: onSave,
                onMove: (_, __) async {},
                onUploadImage: (_, __) async => '',
              ))));

  testWidgets('persisted preview default opens a rendered note',
      (tester) async {
    final controller = await settings({'editorMode': 'preview'});
    await tester.pumpWidget(editor(controller, (_, __, ___) async => true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit source'), findsOneWidget);
    expect(find.text('Cell structure'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // Title remains editable.
  });
  testWidgets('autosave uses the saved delay and disabled writing suggestions',
      (tester) async {
    final controller =
        await settings({'autosaveDelay': 1500, 'spellcheck': false});
    var saves = 0;
    await tester.pumpWidget(editor(controller, (_, __, ___) async {
      saves++;
      return true;
    }));
    await tester.pumpAndSettle();
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.last.autocorrect, false);
    expect(fields.last.enableSuggestions, false);
    await tester.enterText(
        find.byType(TextField).last, 'Updated academic content');
    await tester.pump(const Duration(milliseconds: 1499));
    expect(saves, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(saves, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(saves, 1);
  });
}

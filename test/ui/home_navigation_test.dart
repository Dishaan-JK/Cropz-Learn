import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/data/app_settings.dart';
import 'package:lumi_learning_app/ui/app.dart';

void main() {
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets(
        'Home returns from Settings and Canvas with existing notes at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(const LumiWebApp());
        await tester.pumpAndSettle();
        Future<void> navigate(String label) async {
          if (width < 600) {
            await tester.tap(find.byTooltip('Open navigation'));
            await tester.pumpAndSettle();
          }
          if (width >= 600 && width < 1280) {
            await tester.tap(find.byTooltip(label).first);
          } else {
            await tester.tap(find.text(label).first);
          }
          await tester.pumpAndSettle();
        }

        await navigate('Settings');
        expect(find.text('Personal details'), findsOneWidget);
        await navigate('Home');
        expect(find.text('A workspace for ideas that stick.'), findsOneWidget);
        expect(find.text('Create a note'), findsOneWidget);
        expect(find.text('Create your first note'), findsNothing);
        expect(find.text('Open Artifacts'), findsOneWidget);
        await tester.tap(find.text('Open Canvas'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await navigate('Home');
        expect(find.text('A workspace for ideas that stick.'), findsOneWidget);
        await tester.tap(find.text('Open Artifacts'));
        await tester.pumpAndSettle();
        expect(find.text('Your learning, collected.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                final path = request.url.path;
                if (path == '/api/application-settings') {
                  return http.Response(
                      jsonEncode(
                          {...AppSettings.defaults, 'rotateAccent': false}),
                      200);
                }
                if (path == '/api/notes') {
                  return http.Response(
                      jsonEncode([
                        {
                          'id': 'note-one',
                          'title': 'Existing biology note',
                          'content': 'ATP',
                          'updatedAt': '2026-10-19T00:00:00Z',
                        }
                      ]),
                      200);
                }
                if (path == '/api/profile') {
                  return http.Response('{"preferences":[]}', 200);
                }
                if (path == '/api/workspace/status') {
                  return http.Response('{"service":"Online"}', 200);
                }
                return http.Response('[]', 200);
              }));
    });
  }
}

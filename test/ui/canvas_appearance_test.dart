import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/canvas_background.dart';
import 'package:lumi_learning_app/ui/learning_views.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';
import 'package:lumi_learning_app/ui/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['LUMI_CAPTURE_CANVAS'] == '1') {
      for (final entry in {
        'DM Sans': 'assets/fonts/DMSans-Variable.ttf',
        'Lora': 'assets/fonts/Lora-Variable.ttf',
        'packages/lucide_icons_flutter/Lucide':
            'packages/lucide_icons_flutter/assets/lucide.ttf'
      }.entries) {
        await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
            .load();
      }
    }
  });
  for (final dark in [false, true]) {
    for (final width in [390.0, 1180.0]) {
      testWidgets(
          'Canvas saved colours, pan, zoom and card actions $width dark=$dark',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = SettingsController(
            api: LumiApi(
                client: MockClient((request) async => http.Response(
                    jsonEncode({
                      'canvasPattern': dark ? 'dots' : 'grid',
                      'canvasBackgroundLight': '#EAF0E9',
                      'canvasBackgroundDark': '#202833',
                      'canvasPatternLight': '#ABCDEF',
                      'canvasPatternDark': '#567890',
                    }),
                    200))));
        addTearDown(settings.dispose);
        await settings.load();
        var selected = false, saved = false;
        final note = Note(
            id: 'n1',
            title: 'Cell energy',
            content: 'Mitochondria produce ATP.',
            updatedAt: DateTime(2026));
        final canvas = LearningCanvas(
            id: 'c1',
            title: 'Biology connections',
            description: '',
            noteIds: ['n1'],
            updatedAt: DateTime(2026));
        final capture = GlobalKey();
        await tester.pumpWidget(AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            theme: dark ? LumiTheme.dark() : LumiTheme.light(),
            home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                    body: CanvasView(
                  notes: [note],
                  canvases: [canvas],
                  selectedCanvasId: 'c1',
                  onCanvasChanged: (_) {},
                  onSelect: (_) => selected = true,
                  onPositionsChanged: (_, __) async => saved = true,
                  onCreateCanvas: () {},
                  onSubmitQuiz: (_, __, ___) async => {},
                ))),
          ),
        ));
        await tester.pumpAndSettle();
        final background = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<CanvasPatternPainter>()
            .single;
        expect(background.pattern, dark ? 'dots' : 'grid');
        expect(background.background, Color(dark ? 0xFF202833 : 0xFFEAF0E9));
        await tester.tap(find.text('Cell energy'));
        expect(selected, isTrue);
        await tester.drag(find.text('Cell energy'), const Offset(100, 40));
        await tester.pumpAndSettle();
        expect(saved, isTrue);
        final transform = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
        await tester.tap(find.byTooltip('Reset view'));
        await tester.pumpAndSettle();
        expect(transform.value, Matrix4.identity());
        await tester.dragFrom(const Offset(350, 550), const Offset(-40, -25));
        await tester.pumpAndSettle();
        expect(transform.value.storage[12], isNot(0));
        if (Platform.environment['LUMI_CAPTURE_CANVAS'] == '1') {
          await tester.runAsync(() async {
            final boundary = capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                'build/canvas-review/canvas-${width.toInt()}-${dark ? 'dark' : 'light'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

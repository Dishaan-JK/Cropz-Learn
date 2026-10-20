import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/local_model_settings.dart';
import 'package:lumi_learning_app/ui/lumi_theme.dart';

void main() {
  for (final width in [390.0, 1180.0]) {
    for (final allowed in [false, true]) {
      testWidgets(
          'Hugging Face check/download/activation $width allowed=$allowed',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var started = false, activated = false, callback = false;
        final host = {
          'supported': true,
          'cpu': {'name': 'Intel Core', 'threads': 8, 'usagePercent': 10},
          'memory': {'totalBytes': 32e9, 'availableBytes': 24e9},
          'storage': {'availableBytes': 100e9},
          'gpus': [
            {
              'vendor': 'Intel',
              'name': 'Integrated Intel Graphics',
              'memoryType': 'shared'
            }
          ],
          'ollama': {'available': true, 'version': '0.33.2'}
        };
        final runtime = {
          'execution': 'GPU offload confirmed',
          'toolCallVerified': true,
          'modelAllocatedBytes': 2e9,
          'allocationOverheadBytes': .5e9,
          'gpuAllocatedBytes': 1e9,
          'peakSystemCpuPercent': 20,
          'peakSystemGpuPercent': null,
          'systemRamDeltaBytes': 2e9,
          'note': 'Smoke test only'
        };
        final api = LumiApi(client: MockClient((request) async {
          final action = request.url.path.split('/').last;
          final result = switch (action) {
            'hardware' => host,
            'job' => {
                'job': started
                    ? {
                        'id': 'j1',
                        'status': 'ready',
                        'modelName': 'lumi-hf-test',
                        'message': 'Verified',
                        'runtime': runtime
                      }
                    : null
              },
            'inspect' => {
                'repo': 'owner/chat',
                'files': [
                  {'name': 'chat-Q4_K_M.gguf', 'bytes': 1e9}
                ]
              },
            'pick-folder' => {
                'cancelled': false,
                'path': '/models/from-picker'
              },
            'catalog' => {
                'source': 'huggingface',
                'items': [
                  {
                    'id': 'owner/chat',
                    'author': 'owner',
                    'pipelineTag': 'text-generation',
                    'downloads': 42
                  }
                ],
                'nextCursor': null
              },
            'check' => {
                'checkId': 'c1',
                'hardware': host,
                'assessment': {
                  'allowed': allowed,
                  'blocks': allowed ? [] : ['Insufficient RAM'],
                  'warnings': ['Estimate only'],
                  'difficulty': 'GPU candidate',
                  'fileBytes': 1e9,
                  'estimatedRamBytes': 4e9,
                  'runtimeOverheadBytes': 1e9,
                  'cacheAllowanceBytes': 2e9,
                  'requiresCaution': false,
                  'currentAvailableRamBytes': 24e9,
                  'availableRamAfterLoadBytes': 20e9,
                  'expectedCpuLoad': 'Conditional',
                  'expectedGpuLoad': 'Requires runtime verification'
                }
              },
            'download' => {
                'id': 'j1',
                'status': 'downloading',
                'modelName': 'lumi-hf-test',
                'message': 'Downloading',
                'completed': 1,
                'total': 100
              },
            'activate' => {'model': 'lumi-hf-test'},
            'config' => {
                'providerId': 'ollama',
                'provider': 'Local Ollama',
                'model': 'lumi-hf-test'
              },
            _ => {},
          };
          if (action == 'download') {
            expect(allowed, true);
            started = true;
          }
          if (action == 'activate') {
            expect(started, true);
            activated = true;
          }
          return http.Response(jsonEncode(result), 200);
        }));
        addTearDown(api.close);
        await tester.pumpWidget(MaterialApp(
            theme: LumiTheme.light(),
            home: Scaffold(
                body: SingleChildScrollView(
              child: LocalModelSettings(
                  api: api, onActivated: () => callback = true),
            ))));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browse popular models'));
        await tester.pumpAndSettle();
        expect(find.text('owner/chat'), findsOneWidget);
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(find.text('Selected model: owner/chat'), findsOneWidget);
        await tester.ensureVisible(find.text('Check compatibility'));
        await tester.tap(find.text('Check compatibility'));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'Choose the existing Ollama model folder before checking this download.'),
            findsOneWidget);
        await tester.tap(find.text('Choose folder in File Manager'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(find.byWidgetPredicate((widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Ollama model folder'))
                .controller!
                .text,
            '/models/from-picker');
        await tester.enterText(
            find.byWidgetPredicate((widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Ollama model folder'),
            '/models');
        await tester.ensureVisible(find.text('Check compatibility'));
        await tester.tap(find.text('Check compatibility'));
        await tester.pumpAndSettle();
        final download =
            find.widgetWithText(FilledButton, 'Download and use for Lumi');
        await tester.ensureVisible(download);
        expect(
            tester.widget<FilledButton>(download).onPressed != null, allowed);
        if (allowed) {
          await tester.tap(download);
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(activated, true);
          expect(callback, true);
          expect(
              find.text(
                  'Beta testing: Local model support is still being tested. Tool calling, performance, and results can vary by model and hardware.'),
              findsOneWidget);
          expect(find.text('Agent connection: Active'), findsOneWidget);
          expect(find.text('lumi-hf-test'), findsNothing);
          expect(find.text('Model size: 0.93 GiB'), findsOneWidget);
          expect(find.text('RAM overhead: 0.47 GiB'), findsOneWidget);
          expect(
              find.text('Stop Lumi model work and unload RAM'), findsOneWidget);
        } else {
          expect(find.text('Download blocked'), findsOneWidget);
          expect(started, false);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

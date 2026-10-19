import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/backend/app_settings_store.dart';
import 'package:lumi_learning_app/data/app_settings.dart';

void main() {
  test('rejects unknown, mistyped, unsupported and unbounded settings', () {
    for (final patch in <Map<String, dynamic>>[
      {'apiKey': 'secret'},
      {'theme': true},
      {'theme': 'neon'},
      {'questionCount': 21},
      {'autosaveDelay': -1},
      {'recentLimit': 999},
      {'workspaceName': '   '},
      {'displayName': 'a\nb'},
      {'canvasPattern': 'stripes'},
      {'canvasBackgroundLight': 'red'},
      {'canvasBackgroundDark': '#12345'},
      {'canvasPatternLight': '#00FF00FF'},
      {'canvasPatternDark': '#GGGGGG'},
    ]) {
      expect(() => AppSettings(patch), throwsFormatException);
    }
  });
  test('serializes concurrent patches and restores the committed values',
      () async {
    final dir = await Directory.systemTemp.createTemp('lumi-settings-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/preferences.json');
    final store = AppSettingsStore(file);
    await Future.wait([
      store.save({
        'theme': 'dark',
        'canvasPattern': 'grid',
        'canvasBackgroundDark': '#102030',
        'canvasPatternDark': '#567890'
      }),
      store.save({'workspaceName': 'Biology'})
    ]);
    final restored = AppSettingsStore(file);
    await restored.load();
    expect(restored.settings.text('canvasPattern'), 'grid');
    expect(restored.settings.text('canvasBackgroundDark'), '#102030');
    expect(restored.settings.text('canvasPatternDark'), '#567890');
    expect(restored.settings.text('canvasBackgroundLight'), '#F4F1E8');
    expect(restored.settings.text('theme'), 'dark');
    expect(restored.settings.text('workspaceName'), 'Biology');
    expect(restored.settings.flag('coachContext'), true);
    expect(await File('${file.path}.tmp').exists(), false);
    expect(() => store.save({'unknown': 1}), throwsFormatException);
    expect(restored.settings.text('theme'), 'dark');
  });
  test('failed writes do not commit in-memory preferences and queue recovers',
      () async {
    final dir = await Directory.systemTemp.createTemp('lumi-settings-failure-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/preferences.json');
    await Directory('${file.path}.tmp').create();
    final store = AppSettingsStore(file);
    await expectLater(
        store.save({'theme': 'dark'}), throwsA(isA<FileSystemException>()));
    expect(store.settings.text('theme'), 'light');
    await Directory('${file.path}.tmp').delete();
    await store.save({'theme': 'system'});
    expect(store.settings.text('theme'), 'system');
  });
}

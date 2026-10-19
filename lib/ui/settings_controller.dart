import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/app_settings.dart';
import '../data/lumi_api.dart';
import 'appearance_storage.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({LumiApi? api}) : _api = api ?? LumiApi() {
    try {
      final cached = readAppearanceValue('lumi.application-settings');
      if (cached != null) {
        _settings = AppSettings(jsonDecode(cached) as Map<String, dynamic>);
      }
    } on Object {/* Ignore an obsolete or unavailable browser cache. */}
  }
  final LumiApi _api;
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;
  final Map<String, dynamic> pending = {};
  bool _disposed = false;
  bool loaded = false;
  String? error;
  Future<void> load() async {
    try {
      final next = AppSettings(await _api.applicationSettings());
      if (_disposed) return;
      _settings = next;
      _cache();
      error = null;
    } on Object {
      if (_disposed) return;
      error =
          'Could not load application preferences. Check the local service and retry.';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save(Map<String, dynamic> patch) async {
    final submitted = AppSettings.validate(patch);
    final next = AppSettings(await _api.saveApplicationSettings(submitted));
    if (_disposed) return;
    _settings = next;
    for (final entry in submitted.entries) {
      if (pending[entry.key] == entry.value) pending.remove(entry.key);
    }
    error = null;
    _cache();
    notifyListeners();
  }

  void _cache() {
    writeAppearanceValue(
        'lumi.application-settings', jsonEncode(_settings.values));
    writeAppearanceValue('lumi.theme.mode', _settings.text('theme'));
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}

class AppSettingsScope extends InheritedNotifier<SettingsController> {
  const AppSettingsScope(
      {required SettingsController controller, required super.child, super.key})
      : super(notifier: controller);
  static SettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
  static AppSettings settingsOf(BuildContext context) =>
      maybeOf(context)?.settings ?? AppSettings();
}

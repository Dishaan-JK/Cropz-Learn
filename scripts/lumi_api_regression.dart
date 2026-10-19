import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lumi_learning_app/data/lumi_api.dart';

Future<void> main() async {
  Uri? requested;
  final api = LumiApi(
    baseUrl: 'http://localhost:8080',
    client: MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode([
          {
            'id': 'n1',
            'title': 'Energy',
            'content': 'ATP',
            'folderId': 'f1',
            'updatedAt': '2026-10-11T00:00:00Z',
          },
        ]),
        200,
      );
    }),
  );
  try {
    final result = await api.search('ATP & glucose');
    _check(
      requested!.queryParameters['q'] == 'ATP & glucose',
      'search query URL encoding',
    );
    _check(requested!.path == '/api/search', 'search endpoint path');
    _check(result.single.folderId == 'f1', 'folder data contract');
  } finally {
    api.close();
  }

  final failed = LumiApi(
    client: MockClient((_) async => http.Response('{}', 503)),
  );
  try {
    try {
      await failed.notes();
      throw StateError('Expected a 503 error');
    } on LumiApiException catch (error) {
      _check(error.statusCode == 503, 'HTTP errors retain status code');
    }
  } finally {
    failed.close();
  }

  String? method;
  String? path;
  Map<String, dynamic>? payload;
  var modelListRequested = false;
  final folders = LumiApi(
    baseUrl: 'http://localhost:8080',
    client: MockClient((request) async {
      method = request.method;
      path = request.url.path;
      if (request.body.isNotEmpty) {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
      }
      return http.Response(
        jsonEncode({'id': 'f1', 'name': 'Biology', 'parentId': null}),
        200,
      );
    }),
  );
  try {
    final folder = await folders.createFolder('Biology');
    _check(method == 'POST' && path == '/api/folders', 'folder create route');
    _check(
      payload?['name'] == 'Biology' && folder.id == 'f1',
      'folder create request and response',
    );
    await folders.updateFolder(folder, 'Life Science');
    _check(method == 'PUT' && path == '/api/folders/f1', 'folder rename route');
    _check(payload?['name'] == 'Life Science', 'folder rename payload');
    await folders.deleteFolder(folder);
    _check(
      method == 'DELETE' && path == '/api/folders/f1',
      'folder delete route',
    );
  } finally {
    folders.close();
  }

  final settings = LumiApi(
    baseUrl: 'http://localhost:8080',
    client: MockClient((request) async {
      if (request.method == 'GET') {
        if (request.url.path == '/api/config') {
          return http.Response(
            jsonEncode({'providerId': 'openai', 'model': 'example-model'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'provider': 'Local Ollama',
            'providerId': 'ollama',
            'model': 'qwen2.5:3b',
            'baseUrl': 'http://127.0.0.1:11434/v1',
            'apiKeyConfigured': false,
          }),
          200,
        );
      }
      if (request.url.path == '/api/settings/test') {
        return http.Response(
          jsonEncode({'connected': true, 'message': 'Connection verified.'}),
          200,
        );
      }
      if (request.url.path == '/api/settings/models') {
        modelListRequested = true;
        return http.Response(
          jsonEncode({
            'models': ['example-model'],
          }),
          200,
        );
      }
      method = request.method;
      path = request.url.path;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'saved': true,
          'restartRequired': false,
          'reconnecting': true,
          'apiKeyConfigured': true,
        }),
        200,
      );
    }),
  );
  try {
    final currentSettings = await settings.settings();
    _check(
      currentSettings['providerId'] == 'ollama',
      'provider settings load through API',
    );
    const connection = {
      'provider': 'openai',
      'model': 'example-model',
      'baseUrl': 'https://api.example.test/v1',
      'apiKey': 'user-secret',
    };
    final saved = await settings.saveSettings(connection);
    _check(
      method == 'POST' && path == '/api/settings',
      'provider settings save route',
    );
    _check(
      payload?['apiKey'] == 'user-secret',
      'API key is sent to the backend settings endpoint',
    );
    _check(
      saved['reconnecting'] == true,
      'settings response reports automatic backend reconnect',
    );
    final models = await settings.availableModels(connection);
    _check(modelListRequested, 'model discovery route');
    _check(models.single == 'example-model', 'provider models parse');
    final active = await settings.waitForConfig(
      provider: 'openai',
      model: 'example-model',
    );
    _check(active['provider'] == 'openai', 'wait for active provider config');
    final testMessage = await settings.testSettings(connection);
    _check(
      testMessage == 'Connection verified.',
      'provider connection test parses response',
    );
  } finally {
    settings.close();
  }
  // ignore: avoid_print
  print('Lumi API regression checks passed (17 assertions).');
}

void _check(bool condition, String label) {
  if (!condition) throw StateError('Regression check failed: $label');
}

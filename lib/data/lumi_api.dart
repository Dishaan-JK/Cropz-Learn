import 'dart:convert';

import 'package:http/http.dart' as http;

const _defaultServiceUrl = String.fromEnvironment(
  'LUMI_SERVICE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.createdAt,
    this.folderId,
  });

  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final String? folderId;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        folderId: json['folderId'] as String?,
      );
}

class Folder {
  const Folder({required this.id, required this.name, this.parentId});
  final String id;
  final String name;
  final String? parentId;

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
      );
}

class LearningCanvas {
  const LearningCanvas({
    required this.id,
    required this.title,
    required this.description,
    required this.noteIds,
    this.positions = const {},
    this.quizzes = const [],
    required this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final List<String> noteIds;
  final Map<String, CanvasPosition> positions;
  final List<Map<String, dynamic>> quizzes;
  final DateTime updatedAt;
  final DateTime? createdAt;

  factory LearningCanvas.fromJson(Map<String, dynamic> json) => LearningCanvas(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        noteIds: (json['noteIds'] as List<dynamic>).cast<String>(),
        positions: _readCanvasPositions(json['positions']),
        quizzes: (json['quizzes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((quiz) => Map<String, dynamic>.from(quiz))
            .toList(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  static Map<String, CanvasPosition> _readCanvasPositions(Object? raw) {
    if (raw is! Map) return const {};
    final positions = <String, CanvasPosition>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final point = entry.value as Map;
      if (point['x'] is num && point['y'] is num) {
        positions[entry.key as String] = CanvasPosition(
          (point['x'] as num).toDouble(),
          (point['y'] as num).toDouble(),
        );
      }
    }
    return positions;
  }
}

class CanvasPosition {
  const CanvasPosition(this.x, this.y);
  final double x;
  final double y;

  Map<String, double> toJson() => {'x': x, 'y': y};
}

class AcademicArtifact {
  const AcademicArtifact(
      {required this.id,
      required this.kind,
      required this.title,
      required this.content,
      required this.source,
      required this.sourceId,
      required this.updatedAt,
      this.learningObject});
  final Map<String, dynamic>? learningObject;
  final String id, kind, title, content, source, sourceId;
  final DateTime updatedAt;
  factory AcademicArtifact.fromJson(Map<String, dynamic> json) =>
      AcademicArtifact(
        learningObject: json['learningObject'] == null
            ? null
            : Map<String, dynamic>.from(json['learningObject'] as Map),
        id: json['id'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        source: json['source'] as String,
        sourceId: json['sourceId'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// HTTP boundary for the local Lumi service. Inject a client for offline tests.
class LumiApi {
  LumiApi({String? baseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl ?? _defaultServiceUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;

  void close() => _client.close();

  Future<List<AcademicArtifact>> artifacts() async {
    final response = await _client.get(_base.resolve('/api/artifacts'));
    _check(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => AcademicArtifact.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> submitArtifactQuiz(
      String id, List<int> answers) async {
    final response = await _client.post(
      _base.resolve('/api/artifacts/${Uri.encodeComponent(id)}/attempt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'answers': answers}),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> localModels(String action,
      {Map<String, dynamic>? body}) async {
    if (!const {
      'hardware',
      'job',
      'status',
      'clear',
      'catalog',
      'inspect',
      'pick-folder',
      'check',
      'download',
      'cancel',
      'emergency-stop',
      'activate',
      'agent-capability-test'
    }.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    final uri = _base.resolve('/api/local-models/$action');
    final response = await (body == null
        ? _client.get(uri)
        : _client.post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, String>> config() async {
    final response = await _client.get(_base.resolve('/api/config'));
    _check(response);
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'provider': value['provider'] as String,
      'model': value['model'] as String,
    };
  }

  Future<Map<String, dynamic>> settings() async {
    final response = await _client.get(_base.resolve('/api/settings'));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveSettings(
      Map<String, String> settings) async {
    final response = await _client.post(
      _base.resolve('/api/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applicationSettings() =>
      settingsResource('/api/application-settings');

  Future<Map<String, dynamic>> saveApplicationSettings(
      Map<String, dynamic> values) async {
    final response = await _client.put(
        _base.resolve('/api/application-settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(values));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> settingsResource(String path) async {
    final response = await _client.get(_base.resolve(path));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importWorkspace(
      Map<String, dynamic> workspace) async {
    final response = await _client.post(
      _base.resolve('/api/workspace/import'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(workspace),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<String>> availableModels(Map<String, String> settings) async {
    final response = await _client.post(
      _base.resolve('/api/settings/models'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );
    _check(response);
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    return (value['models'] as List<dynamic>).cast<String>();
  }

  Future<Map<String, String>> waitForConfig({
    required String provider,
    required String model,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _client.get(_base.resolve('/api/config'));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final value = jsonDecode(response.body) as Map<String, dynamic>;
          if (value['providerId'] == provider && value['model'] == model) {
            return {
              'provider': value['providerId'] as String,
              'model': value['model'] as String,
            };
          }
        }
      } on Object catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw LumiApiException(
      0,
      lastError == null
          ? 'The saved connection did not become active in time.'
          : 'The backend did not reconnect. Check that Lumi’s backend is running.',
    );
  }

  Future<String> testSettings(Map<String, String> settings) async {
    final response = await _client.post(
      _base.resolve('/api/settings/test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Provider connection failed.';
      try {
        message = (jsonDecode(response.body) as Map<String, dynamic>)['message']
                as String? ??
            message;
      } on Object {
        // Keep the generic connection error when the backend response is invalid.
      }
      throw LumiApiException(response.statusCode, message);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['message']
            as String? ??
        'Connection verified.';
  }

  Future<List<Note>> notes() async {
    final response = await _client.get(_base.resolve('/api/notes'));
    _check(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList();
  }

  Future<String> uploadAttachment({
    required String base64Data,
    required String contentType,
  }) async {
    final response = await _client.post(
      _base.resolve('/api/attachments/upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': base64Data, 'contentType': contentType}),
    );
    _check(response);
    final id =
        (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
    return '/api/attachments/$id';
  }

  Future<List<Note>> search(String query) async {
    final response = await _client.get(
      _base.replace(path: '/api/search', queryParameters: {'q': query}),
    );
    _check(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList();
  }

  Future<Note> create({String? folderId}) => _write('POST', '/api/notes', {
        'title': 'Untitled note',
        'content': '',
        'folderId': folderId,
      });

  Future<List<Folder>> folders() async {
    final response = await _client.get(_base.resolve('/api/folders'));
    _check(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Folder.fromJson)
        .toList();
  }

  Future<List<LearningCanvas>> canvases() async {
    final response = await _client.get(_base.resolve('/api/canvases'));
    _check(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LearningCanvas.fromJson)
        .toList();
  }

  Future<LearningCanvas> createCanvas({
    required String title,
    required List<String> noteIds,
    String description = '',
  }) async {
    final response = await _client.post(
      _base.resolve('/api/canvases'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'noteIds': noteIds,
      }),
    );
    _check(response);
    return LearningCanvas.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LearningCanvas> updateCanvasLayout(
    LearningCanvas canvas,
    Map<String, CanvasPosition> positions,
  ) async {
    final response = await _client.put(
      _base.resolve('/api/canvases/${Uri.encodeComponent(canvas.id)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'positions': {
          for (final entry in positions.entries)
            entry.key: entry.value.toJson(),
        },
      }),
    );
    _check(response);
    return LearningCanvas.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitCanvasQuiz({
    required String canvasId,
    required String quizId,
    required List<int> answers,
  }) async {
    final response = await _client.post(
      _base.resolve(
          '/api/canvases/${Uri.encodeComponent(canvasId)}/quizzes/${Uri.encodeComponent(quizId)}/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'answers': answers}),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<String>> preferences() async {
    final response = await _client.get(_base.resolve('/api/profile'));
    _check(response);
    return ((jsonDecode(response.body) as Map<String, dynamic>)['preferences']
            as List<dynamic>)
        .cast<String>();
  }

  Future<Map<String, dynamic>> learningRecord() async {
    final response = await _client.get(_base.resolve('/api/learning-record'));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<String>> forgetPreference(String preference) async {
    final response = await _client.delete(
      _base.resolve('/api/profile/preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'preference': preference}),
    );
    _check(response);
    return ((jsonDecode(response.body) as Map<String, dynamic>)['preferences']
            as List<dynamic>)
        .cast<String>();
  }

  Future<List<String>> rememberPreference(String preference) async {
    final response = await _client.post(
      _base.resolve('/api/profile/preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'preference': preference}),
    );
    _check(response);
    return ((jsonDecode(response.body) as Map<String, dynamic>)['preferences']
            as List<dynamic>)
        .cast<String>();
  }

  Future<void> clearPreferences() async {
    final response = await _client.delete(_base.resolve('/api/profile'));
    _check(response);
  }

  Future<void> deleteAgentSession(String sessionId) async {
    final response = await _client.delete(
      _base.resolve('/api/agent-sessions/${Uri.encodeComponent(sessionId)}'),
    );
    _check(response);
  }

  Future<Folder> createFolder(String name, {String? parentId}) async {
    final response = await _client.post(
      _base.resolve('/api/folders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'parentId': parentId}),
    );
    _check(response);
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Folder> updateFolder(Folder folder, String name) async {
    final response = await _client.put(
      _base.resolve('/api/folders/${Uri.encodeComponent(folder.id)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'parentId': folder.parentId}),
    );
    _check(response);
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteFolder(Folder folder) async {
    final response = await _client.delete(
      _base.resolve('/api/folders/${Uri.encodeComponent(folder.id)}'),
    );
    _check(response);
  }

  Future<Note> update(Note note, String title, String content) => _write(
        'PUT',
        '/api/notes/${Uri.encodeComponent(note.id)}',
        {'title': title, 'content': content, 'folderId': note.folderId},
      );

  Future<void> delete(Note note) async {
    final response = await _client.delete(
      _base.resolve('/api/notes/${Uri.encodeComponent(note.id)}'),
    );
    _check(response);
  }

  Future<Note> _write(
      String method, String path, Map<String, Object?> data) async {
    final uri = _base.resolve(path);
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(data);
    final response = method == 'POST'
        ? await _client.post(uri, headers: headers, body: body)
        : await _client.put(uri, headers: headers, body: body);
    _check(response);
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? body['message'] as String?;
      } on Object {
        // Fall back to the HTTP status when the response is not JSON.
      }
      throw LumiApiException(response.statusCode, message);
    }
  }
}

class LumiApiException implements Exception {
  const LumiApiException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
  @override
  String toString() => message ?? 'Local service returned $statusCode';
}

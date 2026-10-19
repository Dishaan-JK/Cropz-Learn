import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lumi_learning_app/data/lumi_api.dart';

void main() {
  test('artifact quiz submissions encode IDs and send only student answers',
      () async {
    final api = LumiApi(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.pathSegments,
          ['api', 'artifacts', 'generated:quiz/one', 'attempt']);
      expect(jsonDecode(request.body), {
        'answers': [0, 2]
      });
      return http.Response('{"score":1,"total":2,"feedback":[]}', 200);
    }));
    addTearDown(api.close);
    expect(
        (await api.submitArtifactQuiz('generated:quiz/one', [0, 2]))['score'],
        1);
  });

  test('library decodes interactive payloads while preserving legacy materials',
      () async {
    final api = LumiApi(
        client: MockClient((_) async => http.Response(
            jsonEncode([
              for (final interactive in [false, true])
                {
                  'id': '$interactive',
                  'kind': 'Flashcards',
                  'title': 'Recall',
                  'content': 'Text',
                  'source': 'Lumi',
                  'sourceId': 'generated',
                  'updatedAt': '2026-10-19T00:00:00Z',
                  if (interactive)
                    'learningObject': {
                      'type': 'flashcards',
                      'cards': [
                        {'front': 'Q', 'back': 'A'}
                      ]
                    },
                }
            ]),
            200)));
    addTearDown(api.close);
    final items = await api.artifacts();
    expect(items.first.learningObject, isNull);
    expect(items.last.learningObject?['type'], 'flashcards');
  });

  test('search encodes query and parses note result', () async {
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
                'updatedAt': '2026-10-11T00:00:00Z',
              }
            ]),
            200);
      }),
    );
    addTearDown(api.close);

    final notes = await api.search('ATP & glucose');
    expect(requested?.path, '/api/search');
    expect(requested?.queryParameters['q'], 'ATP & glucose');
    expect(notes.single.title, 'Energy');
  });

  test('reads provider and model without requiring browser credentials',
      () async {
    final api = LumiApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/config');
        return http.Response(
            jsonEncode({'provider': 'API', 'model': 'test-model'}), 200);
      }),
    );
    addTearDown(api.close);

    expect(await api.config(), {'provider': 'API', 'model': 'test-model'});
  });

  test('saves an explicitly shared preference through the backend', () async {
    final api = LumiApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/profile/preferences');
        expect(jsonDecode(request.body),
            {'preference': 'I prefer concise answers'});
        return http.Response(
          jsonEncode({
            'preferences': ['I prefer concise answers']
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    expect(await api.rememberPreference('I prefer concise answers'),
        ['I prefer concise answers']);
  });

  test('create sends selected folder in JSON body', () async {
    Object? body;
    final api = LumiApi(
      client: MockClient((request) async {
        body = jsonDecode(request.body);
        return http.Response(
            jsonEncode({
              'id': 'n1',
              'title': 'Untitled note',
              'content': '',
              'folderId': 'f1',
              'updatedAt': '2026-10-11T00:00:00Z',
            }),
            201);
      }),
    );
    addTearDown(api.close);

    final note = await api.create(folderId: 'f1');
    expect((body as Map)['folderId'], 'f1');
    expect(note.folderId, 'f1');
  });

  test('non-success response has typed status error', () async {
    final api =
        LumiApi(client: MockClient((_) async => http.Response('{}', 503)));
    addTearDown(api.close);

    await expectLater(api.notes(), throwsA(isA<LumiApiException>()));
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';
import 'package:lumi_learning_app/ui/settings_controller.dart';

void main() {
  test('successful save clears submitted drafts while preserving newer edits',
      () async {
    final response = Completer<http.Response>();
    final controller = SettingsController(
        api: LumiApi(client: MockClient((_) => response.future)));
    addTearDown(controller.dispose);
    controller.pending
        .addAll({'displayName': 'Ada', 'workspaceName': 'Research'});
    final saving = controller.save(Map.of(controller.pending));
    // A user navigates away and makes a newer edit while the request is in flight.
    controller.pending['displayName'] = 'Grace';
    response.complete(http.Response(
        jsonEncode({'displayName': 'Ada', 'workspaceName': 'Research'}), 200));
    await saving;
    expect(controller.settings.text('displayName'), 'Ada');
    expect(controller.pending, {'displayName': 'Grace'});
  });
}

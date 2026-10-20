import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/ui/coach_panel.dart';

void main() {
  test('learning requests route to the appropriate specialist', () {
    expect(learningAgentPathForRequest('Teach me a new topic'),
        '/api/agents/study');
    expect(learningAgentPathForRequest('Create and grade a test'),
        '/api/agents/tester');
    expect(learningAgentPathForRequest('Diagnose my strengths and weaknesses'),
        '/api/agents/reviewer');
    expect(learningAgentPathForRequest('Help me revise this chapter'),
        '/api/assistant');
  });
}

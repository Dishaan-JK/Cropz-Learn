import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_learning_app/data/user_preferences.dart';

void main() {
  test('extracts a direct preference from a remember command', () {
    expect(
      preferenceFromUserMessage('Remember that I prefer concise answers.'),
      'I prefer concise answers',
    );
  });

  test('learns directly stated learning preferences', () {
    expect(
      preferenceFromUserMessage('I learn best with worked examples.'),
      'I learn best with worked examples',
    );
  });

  test('does not save unrelated facts or inferred traits', () {
    expect(preferenceFromUserMessage('I am studying biology.'), isNull);
    expect(preferenceFromUserMessage('Explain this with an example.'), isNull);
  });
}

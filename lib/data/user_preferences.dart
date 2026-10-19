/// Extract only direct, durable learning/communication preferences.
String? preferenceFromUserMessage(String message) {
  final clean = message.trim().replaceFirst(RegExp(r'[.!?]+$'), '').trim();
  final explicitCommand = RegExp(
    r'^(?:please\s+)?remember(?:\s+that)?\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(clean);
  final preference = explicitCommand?.group(1) ?? clean;
  if (!RegExp(r'^(?:I prefer|I learn best|I like|Please use|Avoid)\b',
          caseSensitive: false)
      .hasMatch(preference)) {
    return null;
  }
  return preference.length <= 180 ? preference : null;
}

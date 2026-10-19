import 'package:web/web.dart' as web;

String? readAppearanceValue(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } on Object {
    return null;
  }
}

void writeAppearanceValue(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } on Object {
    // Storage may be disabled by browser privacy settings.
  }
}

void removeAppearanceValue(String key) {
  try {
    web.window.localStorage.removeItem(key);
  } on Object {
    // Storage may be disabled by browser privacy settings.
  }
}

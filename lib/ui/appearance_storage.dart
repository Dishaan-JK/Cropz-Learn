import 'appearance_storage_stub.dart'
    if (dart.library.js_interop) 'appearance_storage_web.dart' as platform;

String? readAppearanceValue(String key) => platform.readAppearanceValue(key);

void writeAppearanceValue(String key, String value) =>
    platform.writeAppearanceValue(key, value);

void removeAppearanceValue(String key) => platform.removeAppearanceValue(key);

import 'note_editor_platform_contract.dart';
import 'note_editor_platform_stub.dart'
    if (dart.library.js_interop) 'note_editor_platform_web.dart' as platform;

export 'note_editor_platform_contract.dart';

Future<PickedImage?> pickImageFile() => platform.pickImageFile();

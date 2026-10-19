import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'note_editor_platform_contract.dart';

Future<PickedImage?> pickImageFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/gif,image/webp';
  final choice = Completer<web.File?>();
  late final StreamSubscription<web.Event> change;
  late final StreamSubscription<web.Event> cancel;
  void finish(web.File? file) {
    if (choice.isCompleted) return;
    choice.complete(file);
    unawaited(change.cancel());
    unawaited(cancel.cancel());
  }

  change = input.onChange.listen((_) => finish(input.files?.item(0)));
  cancel = web.EventStreamProviders.cancelEvent
      .forTarget(input)
      .listen((_) => finish(null));
  input.click();
  final file = await choice.future;
  if (file == null) return null;
  final reader = web.FileReader();
  final loaded = reader.onLoadEnd.first;
  reader.readAsDataURL(file);
  await loaded;
  final result = reader.result;
  if (result == null || !result.isA<JSString>()) return null;
  final dataUrl = (result as JSString).toDart;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  return PickedImage(
    name: file.name,
    contentType: file.type,
    size: file.size,
    base64: dataUrl.substring(comma + 1),
  );
}

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'settings_download_stub.dart';
export 'settings_download_stub.dart' show PickedSettingsFile;

Future<void> downloadSettingsFile(String name, String contents) async {
  final blob = web.Blob(
      [contents.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Keep the URL alive until the browser has consumed the download.
  Future<void>.delayed(
      const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

Future<PickedSettingsFile?> pickWorkspaceImportFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'application/json,.json';
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
  if (file.size > 300 * 1024 * 1024) {
    throw const FormatException(
        'Choose a workspace export smaller than 300 MiB.');
  }
  final reader = web.FileReader();
  final loaded = reader.onLoadEnd.first;
  reader.readAsText(file);
  await loaded;
  final result = reader.result;
  if (result == null || !result.isA<JSString>()) {
    throw const FormatException('The selected file could not be read as JSON.');
  }
  return PickedSettingsFile(
      name: file.name, contents: (result as JSString).toDart);
}

void refreshAfterWorkspaceImport() => web.window.location.reload();

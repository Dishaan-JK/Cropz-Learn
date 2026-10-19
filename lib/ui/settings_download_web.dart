import 'dart:js_interop';
import 'package:web/web.dart' as web;

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

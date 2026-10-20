Future<void> downloadSettingsFile(String name, String contents) async {
  throw UnsupportedError('File downloads are available in Lumi’s web app.');
}

class PickedSettingsFile {
  const PickedSettingsFile({required this.name, required this.contents});
  final String name;
  final String contents;
}

Future<PickedSettingsFile?> pickWorkspaceImportFile() async {
  throw UnsupportedError('Workspace imports are available in Lumi’s web app.');
}

void refreshAfterWorkspaceImport() {}

import '../data/lumi_api.dart';

String folderPathLabel(Folder folder, List<Folder> folders) {
  final byId = {for (final item in folders) item.id: item};
  final names = <String>[folder.name];
  final visited = <String>{folder.id};
  var parentId = folder.parentId;
  while (parentId != null && visited.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) break;
    names.add(parent.name);
    parentId = parent.parentId;
  }
  return names.reversed.join(' / ');
}

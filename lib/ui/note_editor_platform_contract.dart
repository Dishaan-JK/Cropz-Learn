class PickedImage {
  const PickedImage(
      {required this.name,
      required this.contentType,
      required this.size,
      required this.base64});
  final String name;
  final String contentType;
  final int size;
  final String base64;
}

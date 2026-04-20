class PickedBrowserFile {
  final List<int> bytes;
  final String? mimeType;
  final String? name;

  const PickedBrowserFile({
    required this.bytes,
    this.mimeType,
    this.name,
  });
}

Future<PickedBrowserFile?> pickSingleImageFile({
  List<String> accept = const ['image/*'],
}) async {
  throw UnsupportedError('Browser file picking is only supported on web.');
}

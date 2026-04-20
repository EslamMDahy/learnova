import 'dart:typed_data';

class PickedBrowserFile {
  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;

  const PickedBrowserFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
  });
}

Future<List<PickedBrowserFile>> pickBrowserFiles({
  required List<String> acceptedExtensions,
  bool multiple = true,
}) async {
  throw UnsupportedError('Browser file picker is only supported on web.');
}

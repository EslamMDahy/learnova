import 'dart:typed_data';

Future<void> uploadBinaryToSignedUrlImpl({
  required String uploadUrl,
  required Uint8List bodyBytes,
  required String contentType,
  Map<String, String> headers = const <String, String>{},
}) async {
  throw UnsupportedError('Signed URL browser upload is unavailable on this platform.');
}

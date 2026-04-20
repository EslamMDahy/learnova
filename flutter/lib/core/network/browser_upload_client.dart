import 'dart:typed_data';

import 'browser_upload_client_stub.dart'
    if (dart.library.html) 'browser_upload_client_web.dart' as impl;

Future<void> uploadBinaryToSignedUrl({
  required String uploadUrl,
  required Uint8List bodyBytes,
  required String contentType,
  Map<String, String> headers = const <String, String>{},
}) {
  return impl.uploadBinaryToSignedUrlImpl(
    uploadUrl: uploadUrl,
    bodyBytes: bodyBytes,
    contentType: contentType,
    headers: headers,
  );
}

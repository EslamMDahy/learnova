import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> uploadBinaryToSignedUrlImpl({
  required String uploadUrl,
  required Uint8List bodyBytes,
  required String contentType,
  Map<String, String> headers = const <String, String>{},
}) {
  final completer = Completer<void>();

  final xhr = html.HttpRequest()
    ..open('PUT', uploadUrl)
    ..setRequestHeader('Content-Type', contentType);

  for (final entry in headers.entries) {
    xhr.setRequestHeader(entry.key, entry.value);
  }

  xhr.onLoad.listen((_) {
    final status = xhr.status ?? 0;
    if (status >= 200 && status < 400) {
      completer.complete();
      return;
    }
    completer.completeError(
      Exception('Signed upload failed: HTTP $status - ${xhr.responseText}'),
    );
  });

  xhr.onError.listen((_) {
    completer.completeError(Exception('Signed upload network error'));
  });

  xhr.send(bodyBytes.buffer);
  return completer.future;
}

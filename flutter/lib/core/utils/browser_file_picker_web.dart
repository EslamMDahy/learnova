// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
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
  final completer = Completer<List<PickedBrowserFile>>();
  final accepted = acceptedExtensions.join(',');
  final input = html.FileUploadInputElement()
    ..accept = accepted
    ..multiple = multiple;

  input.onChange.listen((_) async {
    final selected = input.files;
    if (selected == null || selected.isEmpty) {
      completer.complete(const []);
      return;
    }

    final files = <PickedBrowserFile>[];
    for (final file in selected) {
      files.add(await _readFile(file));
    }
    completer.complete(files);
  });

  input.click();
  return completer.future;
}

Future<PickedBrowserFile> _readFile(html.File file) async {
  final completer = Completer<PickedBrowserFile>();
  final reader = html.FileReader();

  reader.onLoad.listen((_) {
    final result = reader.result;
    final bytes = result is Uint8List
        ? result
        : Uint8List.view(result as ByteBuffer);
    completer.complete(PickedBrowserFile(
      name: file.name,
      mimeType: file.type,
      sizeBytes: bytes.length,
      bytes: bytes,
    ),);
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}

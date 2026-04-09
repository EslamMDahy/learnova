/// Stub implementation for non-web platforms.
///
/// On web, use conditional import with [file_download_web.dart].
void downloadTextFile({required String filename, required String content, String mimeType = 'text/plain'}) {
  // No-op on non-web (or you can show a toast/snackbar where used).
}

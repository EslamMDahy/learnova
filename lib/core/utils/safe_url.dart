/// Minimal URL validation for external launches.
///
/// This is not a substitute for a full security review, but it prevents
/// unexpected schemes (e.g. `javascript:`) from being launched.
bool isSafeExternalUrl(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// A tiny key/value storage abstraction.
///
/// Constraints:
/// - Web uses sessionStorage/localStorage (via conditional import).
/// - Non-web falls back to in-memory (no persistence) because we cannot add
///   dependencies like shared_preferences under the current constraints.
abstract class KeyValueStore {
  String? getString(String key);
  void setString(String key, String value);
  void remove(String key);
  bool containsKey(String key);
}

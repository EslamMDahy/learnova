// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'key_value_store.dart';

class _WebStorageStore implements KeyValueStore {
  _WebStorageStore(this._storage);

  final Map<String, String> _storage;

  @override
  bool containsKey(String key) => _storage.containsKey(key);

  @override
  String? getString(String key) => _storage[key];

  @override
  void remove(String key) => _storage.remove(key);

  @override
  void setString(String key, String value) => _storage[key] = value;
}

KeyValueStore createSessionStoreImpl() =>
    _WebStorageStore(html.window.sessionStorage);

KeyValueStore createLocalStoreImpl() =>
    _WebStorageStore(html.window.localStorage);

import 'key_value_store.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> _map = <String, String>{};

  @override
  bool containsKey(String key) => _map.containsKey(key);

  @override
  String? getString(String key) => _map[key];

  @override
  void remove(String key) => _map.remove(key);

  @override
  void setString(String key, String value) => _map[key] = value;
}

KeyValueStore createSessionStoreImpl() => _MemoryStore();

KeyValueStore createLocalStoreImpl() => _MemoryStore();

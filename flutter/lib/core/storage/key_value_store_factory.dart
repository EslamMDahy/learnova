import 'key_value_store.dart';

// Conditional import based on platform.
import 'key_value_store_stub.dart'
    if (dart.library.html) 'key_value_store_web.dart';

/// Factory methods for creating storage backends.
///
/// This indirection lets the rest of the codebase avoid importing `dart:html`.
KeyValueStore createSessionStore() => createSessionStoreImpl();

KeyValueStore createLocalStore() => createLocalStoreImpl();

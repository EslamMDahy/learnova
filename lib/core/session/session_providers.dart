import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import 'session_snapshot.dart';

class _SessionRevisionNotifier extends StateNotifier<int> {
  _SessionRevisionNotifier() : super(0) {
    void bump() => state++;

    _listener = bump;
    TokenStorage.listenable.addListener(_listener);
    UserStorage.listenable.addListener(_listener);
  }

  late final VoidCallback _listener;

  @override
  void dispose() {
    TokenStorage.listenable.removeListener(_listener);
    UserStorage.listenable.removeListener(_listener);
    super.dispose();
  }
}

/// A revision counter that increments when either TokenStorage or UserStorage changes.
/// Used to make derived providers react to storage changes.
final sessionRevisionProvider =
    StateNotifierProvider<_SessionRevisionNotifier, int>(
  (ref) => _SessionRevisionNotifier(),
);

/// A derived, read-only session view for routing/guards.
final sessionSnapshotProvider = Provider<SessionSnapshot>((ref) {
  ref.watch(sessionRevisionProvider);
  return SessionSnapshot.fromStorage();
});

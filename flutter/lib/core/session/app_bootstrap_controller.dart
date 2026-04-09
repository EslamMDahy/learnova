import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import '../../features/auth/data/auth_providers.dart';

enum AppBootstrapState { inProgress, done }

final appBootstrapControllerProvider =
    NotifierProvider<AppBootstrapController, AppBootstrapState>(
  AppBootstrapController.new,
);

class AppBootstrapController extends Notifier<AppBootstrapState> {
  @override
  AppBootstrapState build() => AppBootstrapState.inProgress;

  Future<void> bootstrap() async {
    if (state == AppBootstrapState.done) return;

    try {
      final hasToken = TokenStorage.hasToken;
      final isPersisted = TokenStorage.isPersisted;

      // On web: even when sessionStorage is wiped (F5 / tab reopen / browser reopen),
      // the HttpOnly refresh cookie may still be alive. Always attempt a silent
      // refresh before declaring the user a guest.
      //
      // On native: no cookie mechanism — if there is no token and no persist
      // flag the user is definitively a guest.
      const mightHaveCookie = kIsWeb;

      if (!hasToken && !isPersisted && !mightHaveCookie) {
        state = AppBootstrapState.done;
        return;
      }

      if (UserStorage.hasMe && hasToken) {
        state = AppBootstrapState.done;
        return;
      }

      final api = ref.read(authApiProvider);

      if (!hasToken) {
        try {
          final newToken = await api.refresh();
          TokenStorage.saveSession(
            accessToken: newToken,
            persist: isPersisted,
          );
        } catch (_) {
          TokenStorage.clear();
          UserStorage.clear();
          state = AppBootstrapState.done;
          return;
        }
      }

      final raw = await api.me();
      final normalized = _normalize(raw);

      final existing = UserStorage.meJson;
      final Map<String, dynamic> merged;

      if (existing != null) {
        final existingUser = (existing['user'] is Map)
            ? (existing['user'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        final newUser = (normalized['user'] is Map)
            ? (normalized['user'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        final mergedUser = <String, dynamic>{...existingUser};
        newUser.forEach((k, v) {
          if (v != null) mergedUser[k] = v;
        });

        merged = {
          ...existing,
          ...normalized,
          'user': mergedUser,
        };
      } else {
        merged = normalized;
      }

      UserStorage.saveMe(merged, persist: TokenStorage.isPersisted);
    } catch (_) {
      TokenStorage.clear();
      UserStorage.clear();
    } finally {
      state = AppBootstrapState.done;
    }
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    Map<String, dynamic> root = raw;
    final data = root['data'];
    if (data is Map) {
      root = data.cast<String, dynamic>();
    }

    final u = root['user'];
    final user = (u is Map) ? u.cast<String, dynamic>() : root;

    final out = <String, dynamic>{'user': user};

    final orgs = root['organizations'];
    if (orgs is List) {
      out['organizations'] =
          orgs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (orgs is Map) {
      out['organizations'] = [orgs.cast<String, dynamic>()];
    }

    final list =
        (out['organizations'] is List) ? out['organizations'] as List : const [];

    if (list.isNotEmpty && out['selected_organization_id'] == null) {
      final first = list.first;
      if (first is Map) {
        final id = first['id'];
        if (id != null) {
          out['selected_organization_id'] = id;
        }
      }
    }

    return out;
  }
}

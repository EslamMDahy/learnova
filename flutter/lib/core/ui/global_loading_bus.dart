import 'package:dio/dio.dart';

typedef LoadingCallback = void Function();

/// A tiny decoupled bridge between the Network layer (Dio) and UI state.
/// - ApiClient calls beginIfNeeded/endIfNeeded without importing Riverpod.
/// - UI binds actual begin/end callbacks once at app startup.
class GlobalLoadingBus {
  GlobalLoadingBus._();

  static LoadingCallback? _begin;
  static LoadingCallback? _end;

  static void bind({
    required LoadingCallback begin,
    required LoadingCallback end,
  }) {
    _begin = begin;
    _end = end;
  }

  static void unbind() {
    _begin = null;
    _end = null;
  }

  static bool _shouldTrack(RequestOptions o) {
    final extra = o.extra;

    // We don't want the big full-screen loader for every request.
    // Opt-in only: pass Options(extra: {'globalLoading': true}).
    if (extra['silent'] == true) return false;
    return extra['globalLoading'] == true;
  }

  /// Called from Dio onRequest.
  /// Adds a flag on the same request to avoid begin() twice across retries.
  static void beginIfNeeded(RequestOptions o) {
    if (!_shouldTrack(o)) return;

    if (o.extra['__gl_started'] == true) return;
    o.extra['__gl_started'] = true;

    _begin?.call();
  }

  /// Called from Dio onResponse/onError reject.
  /// Adds a flag to avoid end() twice.
  static void endIfNeeded(RequestOptions o) {
    if (o.extra['__gl_started'] != true) return;

    if (o.extra['__gl_ended'] == true) return;
    o.extra['__gl_ended'] = true;

    _end?.call();
  }
}

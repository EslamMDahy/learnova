import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../error/app_error_bus.dart';
import '../error/app_failure.dart';
import '../error/app_failure_presenter.dart';
import '../routing/app_router.dart';
import '../routing/routes.dart';
import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import 'toast.dart';

class GlobalErrorToastListener extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalErrorToastListener({super.key, required this.child});

  @override
  ConsumerState<GlobalErrorToastListener> createState() =>
      _GlobalErrorToastListenerState();
}

class _GlobalErrorToastListenerState
    extends ConsumerState<GlobalErrorToastListener> {
  String? _lastKey;
  bool _authDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AppFailure?>(appErrorProvider, (prev, next) {
      if (next == null) return;

      if (next.type == AppFailureType.validation) {
        AppErrorReporter.clear(ref);
        return;
      }

      final key =
          '${next.type}:${next.message}:${next.statusCode ?? ''}:${next.code ?? ''}';
      if (_lastKey == key) return;
      _lastKey = key;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final navCtx = rootNavigatorKey.currentContext ?? context;

        void go(String location) {
          try {
            GoRouter.of(navCtx).go(location);
          } catch (_) {
            // Fallback (should be rare)
            GoRouter.of(context).go(location);
          }
        }

        // ── AUTH (401) → session-expired dialog + logout + login ──────────
        if (next.isAuthIssue) {
          if (_authDialogOpen) {
            AppErrorReporter.clear(ref);
            return;
          }
          _authDialogOpen = true;
          await _showSessionExpiredDialog(navCtx, next);
          _authDialogOpen = false;
          AppErrorReporter.clear(ref);
          return;
        }

        // ── EMAIL NOT VERIFIED (403 special case) → redirect to verify ────
        if (next.isEmailNotVerified) {
          AppErrorReporter.clear(ref);
          final email = next.extra ?? '';
          if (email.isNotEmpty) {
            TokenStorage.setPendingVerificationEmail(email);
          }
          go(Routes.verifyEmailSentFor(email));
          return;
        }

        // ── SERVER / NETWORK errors → navigate to global error page ───────
        if (next.isServerOrNetworkError) {
          AppErrorReporter.clear(ref);
          final errorType = _errorTypeString(next.type);
          final errorId = _generateErrorId();
          go(Routes.errorPage(
            type: errorType,
            message: next.message,
            errorId: errorId,
          ));
          return;
        }

        // ── Everything else → toast ────────────────────────────────────────
        if (next.type == AppFailureType.warning) {
          AppToast.warning(
            navCtx,
            title: AppFailurePresenter.title(next),
            message: next.message,
          );
        } else {
          AppToast.error(
            navCtx,
            title: AppFailurePresenter.title(next),
            message: next.message,
          );
        }

        AppErrorReporter.clear(ref);
        _lastKey = null;
      });
    });

    return widget.child;
  }

  String _errorTypeString(AppFailureType type) {
    switch (type) {
      case AppFailureType.network:
        return 'network';
      case AppFailureType.timeout:
        return 'timeout';
      default:
        return 'server';
    }
  }

  String _generateErrorId() {
    final rand = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _showSessionExpiredDialog(
    BuildContext ctx,
    AppFailure f,
  ) async {
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: Color(0xFF137FEC), size: 22),
            const SizedBox(width: 10),
            Text(AppFailurePresenter.title(f)),
          ],
        ),
        content: const Text(
          'Your session has expired. Please log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    try {
      TokenStorage.clear();
      UserStorage.clear();
    } catch (_) {}

    try {
      GoRouter.of(ctx).go(Routes.login);
    } catch (_) {}
  }
}

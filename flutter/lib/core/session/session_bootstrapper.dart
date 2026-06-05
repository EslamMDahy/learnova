import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import 'session_bootstrap_controller.dart';
import 'package:learnova/core/theme/app_theme.dart';

class SessionBootstrapper extends ConsumerStatefulWidget {
  final Widget child;
  const SessionBootstrapper({super.key, required this.child});

  @override
  ConsumerState<SessionBootstrapper> createState() => _SessionBootstrapperState();
}

class _SessionBootstrapperState extends ConsumerState<SessionBootstrapper> {
  late final Listenable _storageListenable;
  late final VoidCallback _onStorageChanged;

  @override
  void initState() {
    super.initState();

    _storageListenable =
        Listenable.merge([TokenStorage.listenable, UserStorage.listenable]);
    _onStorageChanged = _maybeBootstrap;
    _storageListenable.addListener(_onStorageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBootstrap());
  }

  @override
  void dispose() {
    _storageListenable.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _maybeBootstrap() {
    if (!mounted) return;

    // Trigger bootstrap when:
    // A) A valid access token exists in sessionStorage but user data is missing.
    // B) No token but persist flag exists (remember-me cold start — controller
    //    will do a silent refresh first, then load /me).
    final needsBootstrap = (TokenStorage.hasToken || TokenStorage.isPersisted) &&
        !UserStorage.hasMe;

    if (!needsBootstrap) return;

    ref.read(sessionBootstrapControllerProvider.notifier).ensureBootstrapped();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final async = ref.watch(sessionBootstrapControllerProvider);

    // Show splash while bootstrapping.
    final needsBootstrap =
        (TokenStorage.hasToken || TokenStorage.isPersisted) && !UserStorage.hasMe;

    if (!needsBootstrap) return widget.child;

    final errMsg = async.hasError
        ? (() {
            final e = async.error;
            final s = e?.toString() ?? '';
            return s.trim().isEmpty
                ? 'Failed to restore your session. Please log in again.'
                : s;
          })()
        : null;

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errMsg == null) ...[
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Restoring session…',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textGray500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          errMsg,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.dangerText,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(sessionBootstrapControllerProvider.notifier)
                            .ensureBootstrapped(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

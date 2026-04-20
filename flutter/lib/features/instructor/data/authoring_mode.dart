import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit toggle for temporary local-only authoring fallbacks.
///
/// Keep this disabled in normal runtime builds so backend data remains the
/// single source of truth. Enable only when intentionally testing incomplete
/// authoring workflows:
///
/// flutter run --dart-define=ENABLE_LOCAL_AUTHORING_FALLBACK=true
const bool kEnableLocalAuthoringFallback =
    bool.fromEnvironment('ENABLE_LOCAL_AUTHORING_FALLBACK', defaultValue: false);

final enableLocalAuthoringFallbackProvider = Provider<bool>(
  (_) => kEnableLocalAuthoringFallback,
);

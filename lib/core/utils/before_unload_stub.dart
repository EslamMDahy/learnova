import 'package:flutter/foundation.dart';

typedef BeforeUnloadShouldBlock = bool Function();

/// Non-web platforms: no-op.
VoidCallback registerBeforeUnload(BeforeUnloadShouldBlock shouldBlock) {
  return () {};
}

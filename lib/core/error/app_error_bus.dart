import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_failure.dart';

final appErrorProvider = StateProvider<AppFailure?>((ref) => null);

class AppErrorReporter {
  const AppErrorReporter._();

  static void report(dynamic ref, AppFailure failure) {
    // ref can be WidgetRef OR Ref (any kind)
    ref.read(appErrorProvider.notifier).state = failure;
  }

  static void clear(dynamic ref) {
    ref.read(appErrorProvider.notifier).state = null;
  }
}

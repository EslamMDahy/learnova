import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final globalLoadingProvider =
    StateNotifierProvider<GlobalLoadingController, bool>(
  (ref) => GlobalLoadingController(),
);

class GlobalLoadingController extends StateNotifier<bool> {
  GlobalLoadingController() : super(false);

  int _counter = 0;

  // timing
  DateTime? _shownAt;
  Timer? _showDelayTimer;
  Timer? _hideDelayTimer;

  // settings
  static const Duration _showDelay = Duration(milliseconds: 120);
  static const Duration _minShowTime = Duration(seconds: 1);

  /// Start a global loading session
  void begin() {
    _counter++;

    
    if (state == true) return;

    
    _showDelayTimer?.cancel();
    _showDelayTimer = Timer(_showDelay, () {
      
      if (_counter > 0 && state == false) {
        state = true;
        _shownAt = DateTime.now();
      }
    });
  }

  /// End a global loading session
  void end() {
    if (_counter <= 0) return;
    _counter--;

    if (_counter > 0) return; 

    
    if (state == false) {
      _showDelayTimer?.cancel();
      return;
    }

    
    final shownAt = _shownAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(shownAt);

    final remaining = _minShowTime - elapsed;

    _hideDelayTimer?.cancel();

    if (remaining.isNegative || remaining == Duration.zero) {
      _hideNow();
    } else {
      _hideDelayTimer = Timer(remaining, _hideNow);
    }
  }

  void _hideNow() {
    _showDelayTimer?.cancel();
    _hideDelayTimer?.cancel();
    state = false;
    _shownAt = null;
  }

  /// Helper: wraps any async call with global loading
  Future<T> run<T>(Future<T> Function() task) async {
    begin();
    try {
      return await task();
    } finally {
      end();
    }
  }

  @override
  void dispose() {
    _showDelayTimer?.cancel();
    _hideDelayTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'global_loading_bus.dart';
import 'global_loading_controller.dart';

class GlobalLoadingBusBinder extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalLoadingBusBinder({super.key, required this.child});

  @override
  ConsumerState<GlobalLoadingBusBinder> createState() => _GlobalLoadingBusBinderState();
}

class _GlobalLoadingBusBinderState extends ConsumerState<GlobalLoadingBusBinder> {
  bool _bound = false;

  @override
  void initState() {
    super.initState();

    // Bind once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bound) return;
      _bound = true;

      final ctrl = ref.read(globalLoadingProvider.notifier);
      GlobalLoadingBus.bind(
        begin: ctrl.begin,
        end: ctrl.end,
      );
    });
  }

  @override
  void dispose() {
    if (_bound) {
      GlobalLoadingBus.unbind();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// share_module_dialog.dart
//
// Public-facing entry point for the Share Module dialog.
// The full implementation (_ShareModuleDialog) lives in materials_tab.dart as
// a private class because it uses coursesRepositoryProvider which is already
// injected into that file via ConsumerStatefulWidget.
//
// This stub documents the intended public API and acts as a future extraction
// point. When coursesRepositoryProvider becomes injectable via a standalone
// ConsumerWidget, the dialog can be moved here.
//
// Current usage (from materials_tab.dart):
//   final targetCourse = await _showManagedDialog<MyCourseItem>(
//     barrierColor: Colors.black.withOpacity(0.35),
//     builder: (_) => _ShareModuleDialog(module: m, currentCourseId: widget.course.id),
//   );
//
// Future public API (once extracted):
//   Future<MyCourseItem?> showShareModuleDialog(
//     BuildContext context, {
//     required ModuleItem module,
//     required int currentCourseId,
//   });

library;
// No exports until _ShareModuleDialog is extracted from materials_tab.dart.

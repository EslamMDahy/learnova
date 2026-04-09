// Re-exports the share dialog that lives in the entry point file.
// The full implementation (_ShareModuleDialog) requires Riverpod ConsumerStatefulWidget
// access to coursesApiProvider, so it is intentionally kept in materials_tab.dart
// and only accessed via _showShareModuleDialog() on the state.
//
// This file is a placeholder to satisfy the planned folder structure.
// Future: extract once coursesApiProvider is injectable without BuildContext.
export '../../../../widgets/course_tabs/materials_tab.dart'
    show ShareModuleDialogAccessor;

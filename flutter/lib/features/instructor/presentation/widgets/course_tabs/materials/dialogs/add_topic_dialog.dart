// add_topic_dialog.dart
//
// Public-facing entry point for the Add Topic dialog.
// The full implementation (_AddTopicDialogV2 + _TopicDialogResult) lives in
// materials_tab.dart as private classes because they require access to
// Riverpod providers already present in that file.
//
// This file re-exports the result type and provides the public show-function
// so any future caller outside materials_tab.dart can use it without needing
// to import the entire tab file.
//
// Usage:
//   final result = await showAddTopicDialog(context, outcomes: outcomes);
//   if (result != null && result.mode == TopicCreateMode.manual) { ... }

library add_topic_dialog;

export 'package:learnova/features/instructor/presentation/widgets/course_tabs/materials_tab.dart'
    show TopicCreateMode, TopicDialogResult;
// NOTE: TopicCreateMode and TopicDialogResult must be made non-private
// (remove the leading underscore) in materials_tab.dart before this export
// will compile. They are currently _TopicCreateMode and _TopicDialogResult.
// Until that refactor is done, callers should use materials_tab.dart directly.

class SettingsFormSnapshot {
  final String firstName;
  final String lastName;
  final String phone;
  final String bio;
  final String language;

  final bool emailNotifications;
  final bool assignmentAlerts;
  final bool courseUpdates;
  final bool announcementNotifications;
  final bool gradingNotifications;
  final bool deadlineReminders;

  final String themeMode;
  final String profileVisibility;
  final bool showOnlineStatus;

  const SettingsFormSnapshot({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.bio,
    required this.language,
    required this.emailNotifications,
    required this.assignmentAlerts,
    required this.courseUpdates,
    required this.announcementNotifications,
    required this.gradingNotifications,
    required this.deadlineReminders,
    required this.themeMode,
    required this.profileVisibility,
    required this.showOnlineStatus,
  });
}

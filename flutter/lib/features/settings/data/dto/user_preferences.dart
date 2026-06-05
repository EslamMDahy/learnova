class UserPreferences {
  final bool emailNotifications;
  final bool assignmentAlerts;
  final bool courseUpdates;
  final bool announcementNotifications;
  final bool gradingNotifications;
  final bool deadlineReminders;

  final String themeMode; // light, dark, system
  final String profileVisibility; // public, private, connections
  final bool showOnlineStatus;

  UserPreferences({
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

  factory UserPreferences.defaults({String themeMode = 'light'}) => UserPreferences(
        emailNotifications: true,
        assignmentAlerts: true,
        courseUpdates: true,
        announcementNotifications: true,
        gradingNotifications: true,
        deadlineReminders: true,
        themeMode: themeMode,
        profileVisibility: 'private',
        showOnlineStatus: true,
      );

  UserPreferences copyWith({
    bool? emailNotifications,
    bool? assignmentAlerts,
    bool? courseUpdates,
    bool? announcementNotifications,
    bool? gradingNotifications,
    bool? deadlineReminders,
    String? themeMode,
    String? profileVisibility,
    bool? showOnlineStatus,
  }) {
    return UserPreferences(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      assignmentAlerts: assignmentAlerts ?? this.assignmentAlerts,
      courseUpdates: courseUpdates ?? this.courseUpdates,
      announcementNotifications:
          announcementNotifications ?? this.announcementNotifications,
      gradingNotifications: gradingNotifications ?? this.gradingNotifications,
      deadlineReminders: deadlineReminders ?? this.deadlineReminders,
      themeMode: themeMode ?? this.themeMode,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    );
  }

  static bool _toBool(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  static String _toStr(dynamic v, {required String fallback}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      emailNotifications:
          _toBool(json['email_notifications'], fallback: true),
      assignmentAlerts: _toBool(json['assignment_alerts'], fallback: true),
      courseUpdates: _toBool(json['course_updates'], fallback: true),
      announcementNotifications:
          _toBool(json['announcement_notifications'], fallback: true),
      gradingNotifications:
          _toBool(json['grading_notifications'], fallback: true),
      deadlineReminders:
          _toBool(json['deadline_reminders'], fallback: true),
      themeMode: _toStr(json['theme_mode'], fallback: 'light'),
      profileVisibility:
          _toStr(json['profile_visibility'], fallback: 'private'),
      showOnlineStatus:
          _toBool(json['show_online_status'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'email_notifications': emailNotifications,
        'assignment_alerts': assignmentAlerts,
        'course_updates': courseUpdates,
        'announcement_notifications': announcementNotifications,
        'grading_notifications': gradingNotifications,
        'deadline_reminders': deadlineReminders,
        'theme_mode': themeMode,
        'profile_visibility': profileVisibility,
        'show_online_status': showOnlineStatus,
      };
}

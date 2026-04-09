class Routes {
  Routes._();

  static const landing = '/';       // Guest entry point (unauthenticated)
  static const home    = '/home';   // Authenticated hub (students / general)

  static const login          = '/login';
  static const signup         = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword  = '/reset-password';
  static const verifyEmail    = '/verify-email';
  static const verifyEmailSent = '/verify-email-sent';
  static const error          = '/error';

  static const settings = '/settings';

  static const admin = '/admin';
  static const adminUsers          = '/admin/users';
  static const adminJoinRequests   = '/admin/join-requests';
  static const adminUpgradePlans   = '/admin/upgrade-plans';
  static const adminSettings       = '/admin/settings';
  static const adminHelp           = '/admin/help';
  static const adminNotifications  = '/admin/notifications';

  static const instructor = '/instructor';
  static const instructorDashboard  = '/instructor/dashboard';
  static const instructorCourses    = '/instructor/courses';
  static const instructorCourseDetails  = '/instructor/courses/:courseSlug';
  static const instructorCourseMaterials    = '/instructor/courses/:courseSlug/materials';
  static const instructorCourseStudents     = '/instructor/courses/:courseSlug/students';
  static const instructorCourseAnalytics    = '/instructor/courses/:courseSlug/analytics';
  static const instructorCourseQuestionBank = '/instructor/courses/:courseSlug/question-bank';
  static const instructorCourseQuizzes      = '/instructor/courses/:courseSlug/quizzes';
  static const instructorQuestionBank  = '/instructor/question-bank';
  static const instructorQuizzes       = '/instructor/quizzes';
  static const instructorSettings      = '/instructor/settings';
  static const instructorHelp          = '/instructor/help';
  static const instructorNotifications = '/instructor/notifications';

  // ── Helpers ───────────────────────────────────────────────────────────────
  static const courseMaterialsSegment    = 'materials';
  static const courseStudentsSegment     = 'students';
  static const courseAnalyticsSegment    = 'analytics';
  static const courseQuestionBankSegment = 'question-bank';
  static const courseQuizzesSegment      = 'quizzes';

  static String courseDetails(String slug)      => '/instructor/courses/$slug';
  static String courseMaterials(String slug)    => '/instructor/courses/$slug/materials';
  static String courseStudents(String slug)     => '/instructor/courses/$slug/students';
  static String courseAnalytics(String slug)    => '/instructor/courses/$slug/analytics';
  static String courseQuestionBank(String slug) => '/instructor/courses/$slug/question-bank';
  static String courseQuizzes(String slug)      => '/instructor/courses/$slug/quizzes';

  /// Navigate to the "check your email" screen after signup or unverified login.
  static String verifyEmailSentFor(String email) =>
      '$verifyEmailSent?email=${Uri.encodeQueryComponent(email)}';

  /// Navigate to the global error page.
  static String errorPage({
    String type = 'server',
    String? message,
    String? errorId,
  }) {
    final params = <String, String>{'type': type};
    if (message != null) params['msg'] = message;
    if (errorId != null) params['id'] = errorId;
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$error?$query';
  }
}

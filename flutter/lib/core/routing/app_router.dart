import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import '../session/session_snapshot.dart';
import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import '../theme/app_theme.dart';

import '../../features/auth/presentation/pages/forget_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/set_new_password_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/verify_email_sent_page.dart';
import '../../shared/pages/home_page.dart';
import '../../shared/pages/landing_page.dart';
import '../../shared/pages/notifications_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/admin/presentation/pages/admin_shell.dart';
import '../../features/admin/presentation/pages/admin_route_pages.dart';
import '../../features/instructor/presentation/pages/instructor_shell.dart';
import '../../features/instructor/presentation/pages/instructor_route_pages.dart';
import '../../features/instructor/presentation/pages/course_details/course_details_page.dart';
import '../../features/instructor/presentation/pages/exam_correction_page.dart';
import '../../features/instructor/presentation/widgets/Quizzes/quiz_screen.dart';
import '../../features/instructor/presentation/controllers/selected_course_provider.dart';
import '../../features/instructor/presentation/course_route_identity.dart';
import '../../features/instructor/data/courses_providers.dart';
import '../../features/student/presentation/pages/student_shell.dart';
import '../../features/student/presentation/pages/dashboard/student_dashboard_page.dart';
import '../../features/student/presentation/pages/courses/student_courses_page.dart';
import '../../features/student/presentation/pages/courses/student_course_details_page.dart';
import '../../features/student/presentation/pages/question_bank/student_question_bank_page.dart';
import '../../features/student/presentation/pages/quiz_history/student_quiz_history_page.dart';
import '../../features/student/presentation/pages/recommendations/student_recommendations_page.dart';
import '../../shared/pages/error_page.dart';
import '../../shared/widgets/empty_state_page.dart';

import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final _routerRefreshListenableProvider = Provider<ValueNotifier<int>>((ref) {
  final n = ValueNotifier<int>(0);
  ref.listen(sessionSnapshotProvider, (_, __) => n.value++);
  ref.onDispose(n.dispose);
  return n;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshListenableProvider);
  final initialSession = SessionSnapshot.fromStorage();

  Page<void> courseDetailsPage(
    GoRouterState state,
    CourseDetailsTab tab,
  ) {
    final slug = state.pathParameters['courseSlug']!;
    final routeCourseId = parseCourseIdFromSlug(slug);

    // Prefer the URL as the source of truth on refresh/deep links.
    final cached = SelectedCourseCache.value;
    if (cached != null && slugMatchesCourse(slug, cached)) {
      return NoTransitionPage(
        key: ValueKey<String>('course-details-$slug'),
        child: CourseDetailsPage(
          courseSlug: slug,
          cachedCourse: cached,
          cachedCourseId: routeCourseId ?? cached.id,
          initialTab: tab,
        ),
      );
    }

    // Fall back to persisted selection only when the URL itself
    // does not carry a parseable course id.
    final courseId = routeCourseId ?? SelectedCourseCache.cachedCourseId;
    return NoTransitionPage(
      key: ValueKey<String>('course-details-$slug'),
      child: CourseDetailsPage(
        courseSlug: slug,
        cachedCourse: null,
        cachedCourseId: courseId,
        initialTab: tab,
      ),
    );
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: _initialLocationSafe(initialSession),
    refreshListenable: refresh,
    redirect: (context, state) {
      try {
        final s = ref.read(sessionSnapshotProvider);
        final path = state.uri.path;

        // ── Token-required routes (guard empty token param) ─────────────────
        if ((path == Routes.verifyEmail || path == Routes.resetPassword) &&
            (state.uri.queryParameters['token'] ?? '').trim().isEmpty) {
          return Routes.login;
        }

        final isAuthed = s.isAuthed;

        // ── Pending email verification (unverified login) ───────────────────
        final pendingEmail = s.pendingVerificationEmail;
        if (pendingEmail != null &&
            !isAuthed &&
            path != Routes.verifyEmailSent &&
            path != Routes.verifyEmail) {
          return Routes.verifyEmailSentFor(pendingEmail);
        }

        // ── Landing / root ───────────────────────────────────────────────────
        if (path == Routes.landing) {
          if (!isAuthed) return null;
          if (!s.hasMe) return Routes.home;
          if (s.isOwner) return Routes.adminUsers;
          if (s.isInstructor) return Routes.instructorDashboard;
          return Routes.studentDashboard;
        }

        // ── Unauthenticated → protected route ───────────────────────────────
        if (!isAuthed && !_isPublicRoute(path)) {
          return Routes.landing;
        }

        // ── Authenticated → auth-only routes ────────────────────────────────
        if (isAuthed && _isAuthOnlyRoute(path)) {
          if (path == Routes.verifyEmail || path == Routes.verifyEmailSent) {
            return null;
          }
          if (!s.hasMe) return Routes.home;
          if (s.isOwner) return Routes.adminUsers;
          if (s.isInstructor) return Routes.instructorDashboard;
          return Routes.studentDashboard;
        }

        // ── Legacy /home → role-based dashboard ─────────────────────────────
        if (path == Routes.home && s.hasMe) {
          if (s.isOwner) return Routes.adminUsers;
          if (s.isInstructor) return Routes.instructorDashboard;
          return Routes.studentDashboard;
        }

        // ── /settings → role-based settings ────────────────────────────────
        if (path == Routes.settings) {
          if (!s.hasMe) return null;
          if (s.isOwner) return Routes.adminSettings;
          if (s.isInstructor) return Routes.instructorSettings;
          return Routes.studentSettings;
        }

        // ── Role guards ──────────────────────────────────────────────────────
        if (path.startsWith(Routes.admin)) {
          if (!s.hasMe) return null;
          if (!s.isOwner) return Routes.home;
          if (path == Routes.admin) return Routes.adminUsers;
        }

        if (path.startsWith(Routes.instructor)) {
          if (!s.hasMe) return null;
          if (!s.isInstructor) {
            return s.isOwner ? Routes.adminUsers : Routes.studentDashboard;
          }
          if (path == Routes.instructor) return Routes.instructorDashboard;
        }

        if (path.startsWith(Routes.student)) {
          if (!s.hasMe) return null;
          if (s.isOwner) return Routes.adminUsers;
          if (s.isInstructor) return Routes.instructorDashboard;
          if (path == Routes.student) return Routes.studentDashboard;
        }

        return null;
      } catch (_) {
        _clearSessionSafe();
        return Routes.landing;
      }
    },
    routes: [
      // ── Landing (guest entry point) ───────────────────────────────────────
      GoRoute(
        path: Routes.landing,
        name: RouteNames.landing,
        builder: (_, __) => const LandingPage(),
      ),

      // ── Authenticated home ────────────────────────────────────────────────
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: Routes.settings,
        name: RouteNames.settings,
        builder: (_, __) => const SettingsPage(),
      ),

      // ── Error / Fallback ──────────────────────────────────────────────────
      GoRoute(
        path: Routes.error,
        name: RouteNames.error,
        builder: (_, state) {
          final type = state.uri.queryParameters['type'] ?? 'server';
          final msg  = state.uri.queryParameters['msg'];
          final errorId = state.uri.queryParameters['id'];
          return ErrorPage(errorType: type, message: msg, errorId: errorId);
        },
      ),

      // ── Auth routes ───────────────────────────────────────────────────────
      GoRoute(
        path: Routes.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.signup,
        name: RouteNames.signup,
        builder: (_, __) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (_, __) => const ForgetPasswordPage(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        name: RouteNames.verifyEmail,
        builder: (_, state) =>
            VerifyEmailPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: Routes.verifyEmailSent,
        name: RouteNames.verifyEmailSent,
        builder: (_, state) {
          final email = state.uri.queryParameters['email'];
          return VerifyEmailSentPage(email: email);
        },
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: RouteNames.resetPassword,
        builder: (_, state) =>
            SetNewPasswordPage(token: state.uri.queryParameters['token']),
      ),

      // ── Admin shell ───────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminUsers,
            name: RouteNames.adminUsers,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminUsersRoutePage()),
          ),
          GoRoute(
            path: Routes.adminJoinRequests,
            name: RouteNames.adminJoinRequests,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminJoinRequestsRoutePage()),
          ),
          GoRoute(
            path: Routes.adminUpgradePlans,
            name: RouteNames.adminUpgradePlans,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminUpgradePlansRoutePage()),
          ),
          GoRoute(
            path: Routes.adminSettings,
            name: RouteNames.adminSettings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminSettingsRoutePage()),
          ),
          GoRoute(
            path: Routes.adminHelp,
            name: RouteNames.adminHelp,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminHelpRoutePage()),
          ),
          GoRoute(
            path: Routes.adminNotifications,
            name: RouteNames.adminNotifications,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminNotificationsRoutePage()),
          ),
        ],
      ),

      // ── Instructor shell ──────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => InstructorShell(child: child),
        routes: [
          GoRoute(
            path: Routes.instructorDashboard,
            name: RouteNames.instructorDashboard,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: InstructorDashboardRoutePage()),
          ),
          GoRoute(
            path: Routes.instructorCourses,
            name: RouteNames.instructorCourses,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: InstructorCourseRoutePage()),
          ),
          GoRoute(
            path: Routes.instructorCourseDetails,
            name: RouteNames.instructorCourseDetails,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.overview),
          ),
          GoRoute(
            path: Routes.instructorCourseMaterials,
            name: RouteNames.instructorCourseMaterials,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.materials),
          ),
          GoRoute(
            path: Routes.instructorCourseOutcomes,
            name: RouteNames.instructorCourseOutcomes,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.outcomes),
          ),
          GoRoute(
            path: Routes.instructorCourseQuestionBank,
            name: RouteNames.instructorCourseQuestionBank,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.questionBank),
          ),
          GoRoute(
            path: Routes.instructorCourseTemplates,
            name: RouteNames.instructorCourseTemplates,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.templates),
          ),
          GoRoute(
            path: Routes.instructorCourseStudents,
            name: RouteNames.instructorCourseStudents,
            pageBuilder: (_, state) =>
                courseDetailsPage(state, CourseDetailsTab.students),
          ),
          GoRoute(
            path: Routes.instructorNotifications,
            name: RouteNames.instructorNotifications,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: NotificationsPage()),
          ),
          GoRoute(
            path: Routes.instructorSettings,
            name: RouteNames.instructorSettings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsPage()),
          ),

          // ── Coming-soon routes: now show a proper empty state ─────────────
          GoRoute(
            path: Routes.instructorQuestionBank,
            name: RouteNames.instructorQuestionBank,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: EmptyStatePage(
                icon: Icons.quiz_outlined,
                title: 'Question Bank',
                description:
                    'Build, organise and reuse questions across all your courses. Coming soon.',
              ),
            ),
          ),
          GoRoute(
            path: Routes.instructorExamCorrection,
            name: RouteNames.instructorExamCorrection,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ExamCorrectionPage(),
            ),
          ),
          GoRoute(
            path: Routes.instructorQuizzes,
            name: RouteNames.instructorQuizzes,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: InstructorQuizzesScreen(),
            ),
          ),
          GoRoute(
            path: Routes.instructorHelp,
            name: RouteNames.instructorHelp,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: EmptyStatePage(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                description:
                    'Browse guides, FAQs and contact the support team. Coming soon.',
              ),
            ),
          ),
        ],
      ),

      // ── Student shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: Routes.studentDashboard,
            name: RouteNames.studentDashboard,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentDashboardPage()),
          ),
          GoRoute(
            path: Routes.studentCourses,
            name: RouteNames.studentCourses,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentCoursesPage()),
          ),
          GoRoute(
            path: Routes.studentCourseDetails,
            name: RouteNames.studentCourseDetails,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentCourseDetailsPage()),
          ),
          GoRoute(
            path: Routes.studentQuestionBank,
            name: RouteNames.studentQuestionBank,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentQuestionBankPage()),
          ),
          GoRoute(
            path: Routes.studentQuizHistory,
            name: RouteNames.studentQuizHistory,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentQuizHistoryPage()),
          ),
          GoRoute(
            path: Routes.studentRecommendations,
            name: RouteNames.studentRecommendations,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentRecommendationsPage()),
          ),
          GoRoute(
            path: Routes.studentNotifications,
            name: RouteNames.studentNotifications,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: NotificationsPage()),
          ),
          GoRoute(
            path: Routes.studentSettings,
            name: RouteNames.studentSettings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: Routes.studentHelp,
            name: RouteNames.studentHelp,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: EmptyStatePage(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                description: 'Browse guides, FAQs and contact support. Coming soon.',
              ),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initialLocationSafe(SessionSnapshot session) {
  try {
    final pending = session.pendingVerificationEmail;
    if (pending != null && !session.hasAccessToken && !session.isPersisted) {
      return Routes.verifyEmailSentFor(pending);
    }
    if (!session.hasAccessToken) return Routes.landing;
    if (session.hasMe && session.isOwner) return Routes.adminUsers;
    if (session.hasMe && session.isInstructor) return Routes.instructorDashboard;
    if (session.hasMe) return Routes.studentDashboard;
    return Routes.home;
  } catch (_) {
    _clearSessionSafe();
    return Routes.landing;
  }
}

bool _isPublicRoute(String path) {
  return path == Routes.landing ||
      _isAuthOnlyRoute(path) ||
      path == Routes.error ||
      path == Routes.verifyEmail ||
      path == Routes.verifyEmailSent;
}

bool _isAuthOnlyRoute(String path) {
  return path == Routes.login ||
      path == Routes.signup ||
      path == Routes.forgotPassword ||
      path == Routes.resetPassword ||
      path == Routes.verifyEmail ||
      path == Routes.verifyEmailSent;
}

void _clearSessionSafe() {
  try {
    TokenStorage.clear();
    UserStorage.clear();
  } catch (_) {}
}

// ── Route names ───────────────────────────────────────────────────────────────

class RouteNames {
  RouteNames._();
  static const landing    = 'landing';
  static const home       = 'home';
  static const login      = 'login';
  static const signup     = 'signup';
  static const forgotPassword  = 'forgotPassword';
  static const verifyEmail     = 'verifyEmail';
  static const verifyEmailSent = 'verifyEmailSent';
  static const resetPassword   = 'resetPassword';
  static const settings  = 'settings';
  static const error     = 'error';

  static const studentDashboard = 'studentDashboard';
  static const studentCourses = 'studentCourses';
  static const studentCourseDetails = 'studentCourseDetails';
  static const studentQuestionBank = 'studentQuestionBank';
  static const studentQuizHistory = 'studentQuizHistory';
  static const studentRecommendations = 'studentRecommendations';
  static const studentSettings = 'studentSettings';
  static const studentHelp = 'studentHelp';
  static const studentNotifications = 'studentNotifications';

  static const instructorDashboard   = 'instructorDashboard';
  static const instructorCourses     = 'instructorCourses';
  static const instructorCourseDetails = 'instructorCourseDetails';
  static const instructorQuestionBank  = 'instructorQuestionBank';
  static const instructorExamCorrection = 'instructorExamCorrection';
  static const instructorQuizzes       = 'instructorQuizzes';
  static const instructorSettings      = 'instructorSettings';
  static const instructorHelp          = 'instructorHelp';
  static const instructorNotifications = 'instructorNotifications';

  static const adminUsers        = 'adminUsers';
  static const adminJoinRequests = 'adminJoinRequests';
  static const adminUpgradePlans = 'adminUpgradePlans';
  static const adminSettings     = 'adminSettings';
  static const adminHelp         = 'adminHelp';
  static const adminNotifications = 'adminNotifications';

  // compat
  static const instructorCourseMaterials    = 'instructorCourseMaterials';
  static const instructorCourseOutcomes     = 'instructorCourseOutcomes';
  static const instructorCourseStudents     = 'instructorCourseStudents';
  static const instructorCourseAnalytics    = 'instructorCourseAnalytics';
  static const instructorCourseQuestionBank = 'instructorCourseQuestionBank';
  static const instructorCourseTemplates    = 'instructorCourseTemplates';
  static const instructorCourseQuizzes      = 'instructorCourseQuizzes';
}

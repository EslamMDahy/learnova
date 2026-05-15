class Endpoints {
  Endpoints._();

  static const _auth     = '/auth';
  static const _orgs     = '/organizations';
  static const _settings = '/settings';
  static const _courses  = '/courses';

  // ─── AUTH ────────────────────────────────────────────────────────────────
  static const login               = '$_auth/login';
  static const signup              = '$_auth/register';
  static const logout              = '$_auth/logout';
  static const forgotPassword      = '$_auth/forgot-password';
  static const resetPassword       = '$_auth/reset-password';
  static const verifyEmail         = '$_auth/verify-email';
  static const resendVerification  = '$_auth/send-verification-email';
  static const checkEmailVerified  = '$_auth/check-email-verified';
  static const me                  = '$_auth/me';
  static const refresh             = '$_auth/refresh';

  // ─── ORGANIZATIONS ───────────────────────────────────────────────────────
  static const createOrganization = _orgs;
  static String joinRequests(String organizationId) =>
      '$_orgs/$organizationId/join-requests';
  static String updateMemberStatus(String organizationId, String orgMemberId) =>
      '$_orgs/$organizationId/members/$orgMemberId/status';

  // ─── COURSES ─────────────────────────────────────────────────────────────
  static const createCourse = _courses;
  static const myCourses    = '$_courses/my';
  static String courseInvitationsUpload(String courseId) =>
      '$_courses/$courseId/invitations/upload';
  static String courseInvitationsSend(String courseId) =>
      '$_courses/$courseId/invitations/send';
  static String courseInvitationsList(String courseId) =>
      '$_courses/$courseId/invitations';
  static const acceptCourseInvitation = '$_courses/invitations/accept';

  // ─── MODULES ─────────────────────────────────────────────────────────────
  static String courseModules(int courseId) =>
      '$_courses/$courseId/modules';
  static String createModule(int courseId) =>
      '$_courses/$courseId/modules';
  static String updateModule(int courseId, int moduleId) =>
      '$_courses/$courseId/modules/$moduleId/update';
  static String deleteModule(int courseId, int moduleId) =>
      '$_courses/$courseId/modules/$moduleId/delete';
  static String copyModule(int courseId, int moduleId) =>
      '$_courses/$courseId/modules/$moduleId/copy';
  static String reorderModules(int courseId) =>
      '$_courses/$courseId/modules/reorder';

  // ─── MATERIALS ───────────────────────────────────────────────────────────
  static String moduleMaterials(int courseId, int moduleId) =>
      '$_courses/$courseId/modules/$moduleId/materials';
  static String initMaterialUpload(int courseId, int moduleId) =>
      '$_courses/$courseId/modules/$moduleId/materials/init-upload';
  static String confirmMaterialUpload(int materialId) =>
      '/materials/$materialId/confirm-upload';
  static String materialDownloadUrl(int courseId, int moduleId, int materialId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/download-url';
  static String deleteMaterial(int courseId, int moduleId, int materialId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId';
  static String reassignMaterial(int materialId) =>
      '/materials/$materialId/reassign';

  // ─── TOPICS ──────────────────────────────────────────────────────────────
  static String materialTopics(int courseId, int moduleId, int materialId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/topics';
  static String getTopic(int courseId, int moduleId, int materialId, int topicId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/topics/$topicId';
  static String updateTopic(int courseId, int moduleId, int materialId, int topicId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/topics/$topicId/update';
  static String deleteTopic(int courseId, int moduleId, int materialId, int topicId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/topics/$topicId/delete';
  static String reorderTopics(int courseId, int moduleId, int materialId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/topics/reorder';

  // ─── LEARNING OUTCOMES ───────────────────────────────────────────────────
  // Base: /courses/{course_id}/learning-outcomes
  static String learningOutcomes(int courseId) =>
      '$_courses/$courseId/learning-outcomes';
  static String getLearningOutcome(int courseId, int outcomeId) =>
      '$_courses/$courseId/learning-outcomes/$outcomeId';
  static String updateLearningOutcome(int courseId, int outcomeId) =>
      '$_courses/$courseId/learning-outcomes/$outcomeId/update';
  static String deleteLearningOutcome(int courseId, int outcomeId) =>
      '$_courses/$courseId/learning-outcomes/$outcomeId/delete';

  // ─── QUESTIONS ───────────────────────────────────────────────────────────
  static String courseQuestions(int courseId) =>
      '$_courses/$courseId/questions';
  static String courseQuestion(int courseId, int questionId) =>
      '$_courses/$courseId/questions/$questionId';
  static String batchCreateQuestions(int courseId, int moduleId, int materialId) =>
      '$_courses/$courseId/modules/$moduleId/materials/$materialId/questions';

  // ─── EXAMS ───────────────────────────────────────────────────────────────
  static String courseExams(int courseId) =>
      '$_courses/$courseId/exams';
  static String exam(int courseId, int examId) =>
      '$_courses/$courseId/exams/$examId';
  static String examQuestions(int courseId, int examId) =>
      '$_courses/$courseId/exams/$examId/questions';

  // ─── SETTINGS ────────────────────────────────────────────────────────────
  static const updateProfile     = '$_settings/profile';
  static const updatePassword    = '$_settings/password';
  static const deleteRequest     = '$_settings/delete/request';
  static const deleteConfirm     = '$_settings/delete/confirm';
  static const getPreferences    = '$_settings/preferences';
  static const updatePreferences = '$_settings/preferences';
  static const avatarUploadUrl   = '$_settings/avatar/upload-url';
  static const avatarConfirm     = '$_settings/avatar/confirm';
}

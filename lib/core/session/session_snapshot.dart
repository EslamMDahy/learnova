import '../storage/token_storage.dart';
import '../storage/user_storage.dart';

/// A read-only view of the current authentication/session state.
///
/// Important distinction on web:
/// - `isPersisted` only means we MAY be able to restore a session via the
///   HttpOnly refresh cookie.
/// - It does NOT mean the user is currently authenticated yet.
///
/// Treating `isPersisted` as authenticated causes protected routes to build
/// before bootstrap finishes, which can trigger premature 401s on feature
/// requests (for example course materials) and incorrectly log the user out.
class SessionSnapshot {
  const SessionSnapshot({
    required this.hasAccessToken,
    required this.isPersisted,
    required this.hasMe,
    required this.isOwner,
    required this.isInstructor,
    required this.pendingVerificationEmail,
  });

  final bool hasAccessToken;
  final bool isPersisted;
  final bool hasMe;
  final bool isOwner;
  final bool isInstructor;
  final String? pendingVerificationEmail;

  /// Current authenticated state.
  ///
  /// Only a live access token counts as authenticated. A persisted flag by
  /// itself merely means bootstrap may still restore the session.
  bool get isAuthed => hasAccessToken;

  /// True when the app may still be able to restore a remembered session.
  bool get canRestoreSession => !hasAccessToken && isPersisted;

  static SessionSnapshot fromStorage() {
    return SessionSnapshot(
      hasAccessToken: TokenStorage.hasToken,
      isPersisted: TokenStorage.isPersisted,
      hasMe: UserStorage.hasMe,
      isOwner: UserStorage.isOwner,
      isInstructor: UserStorage.isInstructor,
      pendingVerificationEmail: TokenStorage.pendingVerificationEmail,
    );
  }
}

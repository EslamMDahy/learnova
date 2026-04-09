/// Abstracts the proactive JWT refresh scheduling concern.
/// AuthRepository depends on this interface instead of the concrete ApiClient,
/// keeping the data layer decoupled from the network layer's internals.
abstract class ITokenRefreshScheduler {
  /// Schedule a proactive silent refresh to fire ~2 minutes before [accessToken] expires.
  void scheduleProactiveRefresh(String accessToken);

  /// Cancel any pending proactive refresh timer (call on logout).
  void cancelProactiveRefresh();
}

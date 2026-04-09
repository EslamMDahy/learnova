class AdminDashboardState {
  final bool loading;
  final String? error;

  
  final String? organizationId;

  const AdminDashboardState({
    this.loading = false,
    this.error,
    this.organizationId,
  });

  
  bool get hasOrganization =>
      organizationId != null && organizationId!.trim().isNotEmpty;

  static const _unset = Object();

  AdminDashboardState copyWith({
    bool? loading,
    Object? error = _unset, 
    String? organizationId,
  }) {
    return AdminDashboardState(
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      organizationId: organizationId ?? this.organizationId,
    );
  }
}

import '../../data/dto/join_request_user.dart';

class UserManagementState {
  final bool loading;
  final List<JoinRequestUser> users;
  final String? error;

  // Pagination (server-driven)
  final int page;
  final int pageSize;
  final int totalCount;

  const UserManagementState({
    this.loading = false,
    this.users = const [],
    this.error,
    this.page = 1,
    this.pageSize = 10,
    this.totalCount = 0,
  });

  int get totalPages {
    if (pageSize <= 0) return 1;
    final total = totalCount <= 0 ? users.length : totalCount;
    return total == 0 ? 1 : (total / pageSize).ceil();
  }

  UserManagementState copyWith({
    bool? loading,
    List<JoinRequestUser>? users,
    String? error,
    bool clearError = false,
    int? page,
    int? pageSize,
    int? totalCount,
  }) {
    return UserManagementState(
      loading: loading ?? this.loading,
      users: users ?? this.users,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

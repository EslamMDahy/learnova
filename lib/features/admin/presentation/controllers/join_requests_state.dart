import '../../data/dto/join_request_user.dart';

class JoinRequestsState {
  final bool loading;
  final String? error;
  final List<JoinRequestUser> users;

  // Total items count (server-driven if supported)
  final int count;

  // Pagination (server-driven)
  final int page;
  final int pageSize;

  const JoinRequestsState({
    this.loading = false,
    this.error,
    this.users = const [],
    this.count = 0,
    this.page = 1,
    this.pageSize = 10,
  });

  bool get hasData => users.isNotEmpty;

  int get totalPages {
    if (pageSize <= 0) return 1;
    final total = count <= 0 ? users.length : count;
    return total == 0 ? 1 : (total / pageSize).ceil();
  }

  static const _unset = Object();

  JoinRequestsState copyWith({
    bool? loading,
    Object? error = _unset, 
    List<JoinRequestUser>? users,
    int? count,
    int? page,
    int? pageSize,
  }) {
    return JoinRequestsState(
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      users: users ?? this.users,
      count: count ?? this.count,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

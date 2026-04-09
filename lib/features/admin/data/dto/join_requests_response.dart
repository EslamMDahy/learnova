import 'join_request_user.dart';

class JoinRequestsResponse {
  /// Total items count (across all pages) when backend supports pagination.
  /// Falls back to [users.length] if not provided.
  final int count;

  /// Current page items.
  final List<JoinRequestUser> users;

  /// Pagination metadata (optional/backward compatible).
  final int page;
  final int pageSize;

  JoinRequestsResponse({
    required this.count,
    required this.users,
    required this.page,
    required this.pageSize,
  });

  int get totalPages {
    if (pageSize <= 0) return 1;
    final total = count <= 0 ? users.length : count;
    return total == 0 ? 1 : (total / pageSize).ceil();
  }

  factory JoinRequestsResponse.fromJson(Map<String, dynamic> json) {
    final rawUsers = (json['users'] as List?) ?? const [];

    final users = <JoinRequestUser>[];
    for (final item in rawUsers) {
      if (item is Map) {
        try {
          users.add(
            JoinRequestUser.fromJson(item.cast<String, dynamic>()),
          );
        } catch (_) {
          
        }
      }
    }

    // Backend may return:
    // - {count, users} (legacy)
    // - {total, page, page_size, users} (paginated)
    // - {count, page, page_size, users} (paginated)
    final page = _toInt(json['page']) ?? 1;
    final pageSize =
        _toInt(json['page_size']) ?? _toInt(json['pageSize']) ?? users.length;

    final count =
        _toInt(json['total']) ?? _toInt(json['count']) ?? users.length;

    return JoinRequestsResponse(
      count: count,
      users: users,
      page: page,
      pageSize: pageSize <= 0 ? users.length : pageSize,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}

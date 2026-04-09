import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class OrganizationsApi {
  final ApiClient _client;
  OrganizationsApi(this._client);

  /// POST /organizations
  /// Backend response: { "organization": { ... } }
  Future<Map<String, dynamic>> createOrganization({
    required String name,
    required String description,
    String? logoUrl,
    CancelToken? cancelToken,
}) async {
    final n = name.trim();
    final d = description.trim();
    final l = logoUrl?.trim();

    
    if (n.isEmpty) {
      throw ArgumentError('Organization name is required.');
    }
    if (d.isEmpty) {
      throw ArgumentError('Organization description is required.');
    }

    final payload = <String, dynamic>{
      'name': n,
      'description': d,
      if (l != null && l.isNotEmpty) 'logo_url': l,
    };

    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.createOrganization,
      data: payload,
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    
    throw const FormatException('Invalid response from createOrganization.');
  }

    /// GET /organizations/{id}/join-requests
  /// Supports query params:
  /// view=pending|accepted, page, page_size, search
  Future<Map<String, dynamic>> joinRequests({
    required String organizationId,
    String view = 'pending',
    int page = 1,
    int pageSize = 10,
    String? search,
    CancelToken? cancelToken,
  }) async {
    final orgId = organizationId.trim();
    if (orgId.isEmpty) {
      throw ArgumentError('organizationId is required.');
    }

    final safeView = (view.trim().toLowerCase() == 'accepted')
        ? 'accepted'
        : 'pending';

    final safePage = page <= 0 ? 1 : page;
    final safePageSize = pageSize <= 0 ? 10 : pageSize;

    final q = <String, dynamic>{
      'view': safeView,
      'page': safePage,
      'page_size': safePageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.joinRequests(orgId),
      queryParameters: q,
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw const FormatException('Invalid response from joinRequests.');
  }
/// PATCH /organizations/{id}/members/{org_member_id}/status
  Future<Map<String, dynamic>> updateMemberStatus({
    required String organizationId,
    required String memberId,
    required String newStatus,
    CancelToken? cancelToken,
}) async {
    final orgId = organizationId.trim();
    final mId = memberId.trim();
    final status = newStatus.trim().toLowerCase();

    if (orgId.isEmpty) {
      throw ArgumentError('organizationId is required.');
    }
    if (mId.isEmpty) {
      throw ArgumentError('memberId is required.');
    }
    if (status.isEmpty) {
      throw ArgumentError('newStatus is required.');
    }

    
    const allowed = {'pending', 'accepted', 'suspended', 'declinate'};
    if (!allowed.contains(status)) {
      throw ArgumentError('Invalid newStatus value: $status');
    }

    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.updateMemberStatus(orgId, mId),
      data: {'new_status': status},
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw const FormatException('Invalid response from updateMemberStatus.');
  }
}

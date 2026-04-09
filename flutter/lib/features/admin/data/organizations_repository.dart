import 'dart:developer';

import 'package:dio/dio.dart';

import 'organizations_api.dart';
import 'dto/create_org_response.dart';
import 'dto/join_requests_response.dart';
import 'dto/organization_out.dart';

class OrganizationsRepository {
  final OrganizationsApi _api;
  OrganizationsRepository(this._api);

  
  static final Map<String, ({DateTime at, JoinRequestsResponse data})> _joinReqCache = {};
  static const Duration _joinReqTtl = Duration(seconds: 20);

  Future<OrganizationOut> createOrganization({
    required String name,
    required String description,
    String? logoUrl,
    CancelToken? cancelToken,
  }) async {
    try {
      final raw = await _api.createOrganization(
        name: name,
        description: description,
        logoUrl: logoUrl,
        cancelToken: cancelToken,
      );

      log('✅ createOrganization raw response: $raw');

      final dto = CreateOrganizationResponse.fromJson(raw);
      return dto.organization;
    } catch (e, st) {
      
      log('❌ createOrganization failed: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Supports backend pagination (page/page_size/search). Backward compatible.
  Future<JoinRequestsResponse> getJoinRequests({
    required String organizationId,
    String view = 'pending',
    int page = 1,
    int pageSize = 10,
    String? search,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final orgId = organizationId.trim();
    final v = view.trim().toLowerCase();
    final safeView = (v == 'accepted') ? 'accepted' : 'pending';
    final safePage = page <= 0 ? 1 : page;
    final safePageSize = pageSize <= 0 ? 10 : pageSize;
    final safeSearch = (search ?? '').trim();

    
    final cacheKey = '$orgId:$safeView:$safePage:$safePageSize:$safeSearch';
    final cached = _joinReqCache[cacheKey];

    if (!forceRefresh && cached != null) {
      final age = DateTime.now().difference(cached.at);
      if (age <= _joinReqTtl) return cached.data;
    }

    try {
      final raw = await _api.joinRequests(
        organizationId: orgId,
        view: safeView,
        page: safePage,
        pageSize: safePageSize,
        search: safeSearch.isEmpty ? null : safeSearch,
        cancelToken: cancelToken,
      );

      log('✅ getJoinRequests raw response: $raw');

      final parsed = JoinRequestsResponse.fromJson(raw);
      _joinReqCache[cacheKey] = (at: DateTime.now(), data: parsed);
      return parsed;
    } catch (e, st) {
      log('❌ getJoinRequests failed: $e', stackTrace: st);
      rethrow;
    }
  }

/// PATCH member status helpers
  Future<Map<String, dynamic>> acceptMember({
    required String organizationId,
    required String memberId,
    CancelToken? cancelToken,
  }) async {
    try {
      final raw = await _api.updateMemberStatus(
        organizationId: organizationId.trim(),
        memberId: memberId.trim(),
        newStatus: 'accepted',
        cancelToken: cancelToken,
      );

      log('✅ acceptMember raw response: $raw');

      // invalidate cache
      _joinReqCache.remove('${organizationId.trim()}:pending');
      _joinReqCache.remove('${organizationId.trim()}:accepted');

      return raw;
    } catch (e, st) {
      log('❌ acceptMember failed: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> declineMember({
    required String organizationId,
    required String memberId,
    CancelToken? cancelToken,
  }) async {
    try {
      
      // Most backends use "rejected" (or "declined"). We standardize to "rejected".
      final raw = await _api.updateMemberStatus(
        organizationId: organizationId.trim(),
        memberId: memberId.trim(),
        newStatus: 'declinate',
        cancelToken: cancelToken,
      );

      log('✅ declineMember raw response: $raw');

      _joinReqCache.remove('${organizationId.trim()}:pending');
      _joinReqCache.remove('${organizationId.trim()}:accepted');

      return raw;
    } catch (e, st) {
      log('❌ declineMember failed: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> suspendMember({
    required String organizationId,
    required String memberId,
    CancelToken? cancelToken,
  }) async {
    try {
      final raw = await _api.updateMemberStatus(
        organizationId: organizationId.trim(),
        memberId: memberId.trim(),
        newStatus: 'suspended',
        cancelToken: cancelToken,
      );

      log('✅ suspendMember raw response: $raw');

      _joinReqCache.remove('${organizationId.trim()}:pending');
      _joinReqCache.remove('${organizationId.trim()}:accepted');

      return raw;
    } catch (e, st) {
      log('❌ suspendMember failed: $e', stackTrace: st);
      rethrow;
    }
  }
}

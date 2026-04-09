import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/storage/user_storage.dart';

import '../../data/organizations_providers.dart';
import 'join_requests_state.dart';

final joinRequestsControllerProvider =
    StateNotifierProvider.autoDispose<JoinRequestsController, JoinRequestsState>(
  (ref) => JoinRequestsController(ref),
);

class JoinRequestsController extends StateNotifier<JoinRequestsState> {
  JoinRequestsController(this._ref) : super(const JoinRequestsState());

  final Ref _ref;

  CancelToken? _loadCancel;
  Timer? _debounce;

  // Query state
  String _organizationId = '';
  String _view = 'pending';
  int _page = 1;
  final int _pageSize = 10;
  String _search = '';

  String _resolveOrgId(String? organizationId) {
    final orgId = (organizationId != null && organizationId.trim().isNotEmpty)
        ? organizationId.trim()
        : (UserStorage.organizationId ?? '').trim();

    if (orgId.isEmpty) {
      
      throw ArgumentError('Missing organizationId.');
    }
    return orgId;
  }

  Future<void> init({
    String? organizationId,
    String view = 'pending',
  }) async {
    final orgId = _resolveOrgId(organizationId);
    final nextView = view.trim().isEmpty ? 'pending' : view.trim();

    final changed = _organizationId != orgId || _view != nextView;
    _organizationId = orgId;
    _view = nextView;

    if (changed) {
      _page = 1;
      _search = '';
    }

    await load(forceRefresh: true);
  }

  
  /// ctrl.load(organizationId: widget.orgId, view: 'pending')
  /// Still supports old calls:
  /// ctrl.load(forceRefresh: true)
  Future<void> load({
    String? organizationId,
    String? view,
    bool forceRefresh = false,
  }) async {
    // Update query context if provided (backward compatible).
    if (organizationId != null) {
      _organizationId = _resolveOrgId(organizationId);
    } else if (_organizationId.isEmpty) {
      // Try fallback from UserStorage, but don't throw unless actually needed
      final fallback = (UserStorage.organizationId ?? '').trim();
      if (fallback.isNotEmpty) _organizationId = fallback;
    }

    if (view != null && view.trim().isNotEmpty) {
      _view = view.trim();
    }

    if (_organizationId.isEmpty) return;

    _cancelOngoing();
    _loadCancel = CancelToken();

    state = state.copyWith(
      loading: true,
      error: null,
      page: _page,
      pageSize: _pageSize,
    );

    try {
      final repo = _ref.read(organizationsRepositoryProvider);

      final res = await repo.getJoinRequests(
        organizationId: _organizationId,
        view: _view,
        page: _page,
        pageSize: _pageSize,
        search: _search,
        forceRefresh: forceRefresh,
        cancelToken: _loadCancel,
      );

      if (_loadCancel?.isCancelled ?? false) return;

      state = state.copyWith(
        loading: false,
        users: res.users,
        count: res.count,
        page: res.page,
        pageSize: res.pageSize,
      );
    } catch (e) {
      if (_loadCancel?.isCancelled ?? false) return;

      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
    }
  }

  void changePage(int page) {
    final safe = page <= 0 ? 1 : page;
    if (safe == _page) return;
    _page = safe;
    load();
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      if (next == _search) return;
      _search = next;
      _page = 1;
      load();
    });
  }

  Future<void> accept({
    String? organizationId,
    required String orgMemberId,
  }) async {
    try {
      final repo = _ref.read(organizationsRepositoryProvider);
      final orgId = _resolveOrgId(organizationId);

      await repo.acceptMember(
        organizationId: orgId,
        memberId: orgMemberId.trim(),
      );

      
      await load(forceRefresh: true);
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);

      state = state.copyWith(error: failure.message);
      rethrow;
    }
  }

  Future<void> decline({
    String? organizationId,
    required String orgMemberId,
  }) async {
    try {
      final repo = _ref.read(organizationsRepositoryProvider);
      final orgId = _resolveOrgId(organizationId);

      await repo.declineMember(
        organizationId: orgId,
        memberId: orgMemberId.trim(),
      );

      
      await load(forceRefresh: true);
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);

      state = state.copyWith(error: failure.message);
      rethrow;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  Future<void> refresh() => load(forceRefresh: true);

  void _cancelOngoing() {
    _debounce?.cancel();
    _loadCancel?.cancel('superseded');
  }

  @override
  void dispose() {
    _cancelOngoing();
    super.dispose();
  }
}

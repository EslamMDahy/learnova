import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/organizations_providers.dart';
import 'user_management_state.dart';

final userManagementControllerProvider =
    StateNotifierProvider<UserManagementController, UserManagementState>(
  (ref) => UserManagementController(ref),
);

class UserManagementController extends StateNotifier<UserManagementState> {
  UserManagementController(this.ref) : super(const UserManagementState());

  final Ref ref;

  CancelToken? _loadCancel;
  Timer? _debounce;

  // Query state
  String _organizationId = '';
  String _view = 'accepted';
  int _page = 1;
  final int _pageSize = 10;
  String _search = '';

  /// Call once when page is opened (or when org changes).
  Future<void> init({
    required String organizationId,
    String view = 'accepted',
  }) async {
    final orgId = organizationId.trim();
    if (orgId.isEmpty) return;

    final nextView = view.trim().isEmpty ? 'accepted' : view.trim();

    // If org/view changed, reset paging & search
    final changed = _organizationId != orgId || _view != nextView;
    _organizationId = orgId;
    _view = nextView;

    if (changed) {
      _page = 1;
      _search = '';
    }

    await load(forceRefresh: true);
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_organizationId.isEmpty) return;

    _cancelOngoing();

    _loadCancel = CancelToken();

    state = state.copyWith(
      loading: true,
      clearError: true,
      page: _page,
      pageSize: _pageSize,
    );

    try {
      final repo = ref.read(organizationsRepositoryProvider);

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
        totalCount: res.count,
        page: res.page,
        pageSize: res.pageSize,
      );
    } catch (e) {
      if (_loadCancel?.isCancelled ?? false) return;
      state = state.copyWith(
        loading: false,
        error: e.toString(),
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

  void refresh() => load(forceRefresh: true);

  void clearError() {
    state = state.copyWith(clearError: true);
  }

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

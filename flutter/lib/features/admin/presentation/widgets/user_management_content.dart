import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/user_storage.dart';
import '../../../../core/ui/toast.dart';
import '../../../../core/utils/organization_member_status.dart';
import '../controllers/user_management_controller.dart';
import '../controllers/user_management_state.dart';
import '../../data/dto/join_request_user.dart';

import '../../../../shared/widgets/app_ui_components.dart';
import '../../../../shared/widgets/async_state_view.dart';

/* ============================================================
   Keep SAME constants for layout widths
============================================================ */
const double _kActionsColW = 72;
const double _kCellLeftPad = 8;
const double _kRowHPad = 16;

class UserManagementContent extends ConsumerStatefulWidget {
  final String? organizationId;

  const UserManagementContent({
    super.key,
    String? organizationId,
    String? orgId, 
  }) : organizationId = organizationId ?? orgId;

  @override
  ConsumerState<UserManagementContent> createState() =>
      _UserManagementContentState();
}

class _UserManagementContentState extends ConsumerState<UserManagementContent> {
  String selectedRole = 'All Roles';
  String selectedStatus = 'All Status';
  final _search = TextEditingController();
  Timer? _searchDebounce;

  String? _lastToastMsg;
  ProviderSubscription<UserManagementState>? _errSub;

  String get _orgId =>
      (widget.organizationId != null && widget.organizationId!.trim().isNotEmpty)
          ? widget.organizationId!.trim()
          : (UserStorage.organizationId ?? '').trim();

  @override
  void initState() {
    super.initState();

    _errSub = ref.listenManual<UserManagementState>(
      userManagementControllerProvider,
      (prev, next) {
        final err = next.error;
        if (err == null) return;

        if (_lastToastMsg == err) return;
        _lastToastMsg = err;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          AppToast.error(
            context,
            title: 'Something went wrong',
            message: err,
          );

          ref.read(userManagementControllerProvider.notifier).clearError();
          _lastToastMsg = null; // allow same error to re-surface on next occurrence
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_orgId.isEmpty) {
        // Show warning only after a brief delay to allow AdminDashboardController
        // to finish its own loading — avoids false warnings for users who do have an org.
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted || _orgId.isNotEmpty) return;
        AppToast.warning(
          context,
          title: 'Action needed',
          message: 'Create/select an organization first.',
        );
        return;
      }

      await ref.read(userManagementControllerProvider.notifier).init(
            organizationId: _orgId,
          );
    });
  }

  @override
  void dispose() {
    _errSub?.close();
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(userManagementControllerProvider);
    final users = _applyFilters(state.users);

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 1100;

        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'User Management',
                    subtitle:
                        'Manage student and instructor accounts, roles, and permissions.',
                  ),
                  const SizedBox(height: 24),

                  _StatsRow(isNarrow: isNarrow, users: state.users),
                  const SizedBox(height: 16),

                  FigmaUmFiltersBar(
                    controller: _search,
                    selectedRole: selectedRole,
                    selectedStatus: selectedStatus,
                    isNarrow: isNarrow,
                    onSearchChanged: (v) {
                      ref.read(userManagementControllerProvider.notifier).search(v);
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 280), () {
                        if (!mounted) return;
                        setState(() {});
                      });
                    },
                    onRoleChanged: (v) => setState(() => selectedRole = v),
                    onStatusChanged: (v) => setState(() => selectedStatus = v),
                    onMoreFilters: () {
                      AppToast.info(
                        context,
                        title: 'Coming soon',
                        message: 'More filters will be available soon.',
                      );
                    },
                    onRefresh: _orgId.isEmpty
                        ? () {}
                        : () => ref
                            .read(userManagementControllerProvider.notifier)
                            .refresh(),
                  ),

                  const SizedBox(height: 16),

                  _UsersTableFigma(
                    isNarrow: isNarrow,
                    loading: state.loading,
                    errorMessage: state.error,
                    users: users,
                    page: state.page,
                    pageSize: state.pageSize,
                    totalCount: state.totalCount,
                    onPrev: (state.page > 1 && !state.loading)
                        ? () => ref.read(userManagementControllerProvider.notifier).changePage(state.page - 1)
                        : null,
                    onNext: (state.page < state.totalPages && !state.loading)
                        ? () => ref.read(userManagementControllerProvider.notifier).changePage(state.page + 1)
                        : null,
                    onRetry: _orgId.isEmpty
                        ? null
                        : () => ref.read(userManagementControllerProvider.notifier)
                            .refresh(),
                    onActionTap: () {
                      AppToast.info(
                        context,
                        title: 'Coming soon',
                        message: 'User actions menu is coming soon.',
                      );
                    },
                  ),
                ],
              ),
        );
      },
    );
  }

  List<JoinRequestUser> _applyFilters(List<JoinRequestUser> users) {
    final q = _search.text.trim().toLowerCase();

    return users.where((u) {
      final roleOk = selectedRole == 'All Roles' ||
          u.systemRole.toLowerCase() == selectedRole.toLowerCase();

      final statusOk = selectedStatus == 'All Status' ||
          _normalizeStatus(u.status) == _normalizeStatus(selectedStatus);

      final searchOk = q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);

      return roleOk && statusOk && searchOk;
    }).toList();
  }

  String _normalizeStatus(String s) {
    try {
      return normalizeOrganizationMemberStatus(s);
    } catch (_) {
      return s.toLowerCase().trim();
    }
  }
}

/* ============================================================
   Stats row (same UI, but stat cards moved to reusable)
============================================================ */
class _StatsRow extends StatelessWidget {
  final bool isNarrow;
  final List<JoinRequestUser> users;

  const _StatsRow({required this.isNarrow, required this.users});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final total = users.length;
    final instructors = users.where((e) {
      final r = e.systemRole.toLowerCase();
      return r == 'teacher' || r == 'instructor';
    }).length;
    final students =
        users.where((e) => e.systemRole.toLowerCase() == 'student').length;
    final pending = users.where((e) => e.status.toLowerCase() == 'pending').length;

    final updated = [
      FigmaUmStatCard(
        title: 'Total Users',
        value: '$total',
        subtitle: '+12% from last month',
        subtitleColor: AppColors.successText,
        iconBg: const Color(0x1A137FEC),
        icon: Icons.people_alt_outlined,
        iconColor: AppColors.primary,
      ),
      FigmaUmStatCard(
        title: 'Active Instructors',
        value: '$instructors',
        subtitle: 'Across 12 Departments',
        subtitleColor: AppColors.cGray500,
        iconBg: AppColors.purpleBg,
        icon: Icons.school_outlined,
        iconColor: AppColors.purpleText,
      ),
      FigmaUmStatCard(
        title: 'Active Students',
        value: '$students',
        subtitle: '+5% new enrollments',
        subtitleColor: AppColors.successText,
        iconBg: AppColors.warningBg,
        icon: Icons.groups_outlined,
        iconColor: AppColors.warningText,
      ),
      FigmaUmStatCard(
        title: 'Pending Approvals',
        value: '$pending',
        subtitle: 'Requires attention',
        subtitleColor: AppColors.warningText,
        iconBg: AppColors.warningSoftBg,
        icon: Icons.hourglass_bottom_rounded,
        iconColor: AppColors.warningText,
        fixedWidth: isNarrow ? null : 319,
      ),
    ];

    if (isNarrow) {
      return Wrap(spacing: 16, runSpacing: 16, children: updated);
    }

    return Row(
      children: [
        Expanded(child: updated[0]),
        const SizedBox(width: 16),
        Expanded(child: updated[1]),
        const SizedBox(width: 16),
        Expanded(child: updated[2]),
        const SizedBox(width: 16),
        SizedBox(width: 319, child: updated[3]),
      ],
    );
  }
}

class _UsersTableFigma extends StatelessWidget {
  final bool isNarrow;
  final bool loading;
  final String? errorMessage;
  final List<JoinRequestUser> users;
  final int page;
  final int pageSize;
  final int totalCount;
  final VoidCallback? onRetry;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onActionTap;

  const _UsersTableFigma({
    required this.isNarrow,
    required this.loading,
    required this.errorMessage,
    required this.users,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onRetry,
    required this.onPrev,
    required this.onNext,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final total = totalCount <= 0 ? users.length : totalCount;
    final from = users.isEmpty ? 0 : ((page - 1) * pageSize + 1);
    final to = users.isEmpty ? 0 : (from + users.length - 1);
    final safeTo = (to > total) ? total : to;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cBorder),
        boxShadow: [
          const BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          FigmaUmTableHeader(
            isNarrow: isNarrow,
            actionsColWidth: _kActionsColW,
            cellLeftPad: _kCellLeftPad,
            rowHPad: _kRowHPad,
          ),

          AsyncStateView(
            loading: loading,
            errorMessage: errorMessage,
            isEmpty: users.isEmpty,
            emptyTitle: 'No users',
            emptyMessage: 'No users match your filters right now.',
            onRetry: onRetry,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.cBorderSoft),
              itemBuilder: (_, i) => _UserRowFigma(
                user: users[i],
                isNarrow: isNarrow,
                onActionTap: onActionTap,
              ),
            ),
          ), 

          FigmaUmTableFooter(
            showingText: 'Showing $from-$safeTo of $total users',
            onPrev: onPrev,
            onNext: onNext,
          ),
        ],
      ),
    );
  }
}

class _UserRowFigma extends StatelessWidget {
  final JoinRequestUser user;
  final bool isNarrow;
  final VoidCallback onActionTap;

  const _UserRowFigma({
    required this.user,
    required this.isNarrow,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      height: 91,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kRowHPad),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: false,
                onChanged: (_) {},
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: AppColors.borderSoft),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: _kCellLeftPad),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.badgeBlueBg,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: AppColors.cBorderSoft),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(user.fullName),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 20 / 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 20 / 14,
                              color: AppColors.cText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 16 / 12,
                              color: AppColors.cGray500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: —',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              height: 20 / 10,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: _kCellLeftPad),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FigmaUmRolePill(role: user.systemRole),
                ),
              ),
            ),

            if (!isNarrow)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: _kCellLeftPad),
                  child: Text(
                    '—',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 20 / 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              ),

            if (!isNarrow)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: _kCellLeftPad),
                  child: Text(
                    '—',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                      color: AppColors.cGray500,
                    ),
                  ),
                ),
              ),

            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: _kCellLeftPad),
                child: FigmaUmStatus(status: user.status),
              ),
            ),

            SizedBox(
              width: _kActionsColW,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    onTap: onActionTap,
                    borderRadius: BorderRadius.circular(9999),
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '—';
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = (a + b).toUpperCase();
    return res.isEmpty ? '—' : res;
  }
}

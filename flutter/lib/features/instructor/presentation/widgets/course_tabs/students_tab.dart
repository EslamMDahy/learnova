import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/endpoints.dart';
import '../../../../../core/network/error_mapper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../features/auth/data/auth_providers.dart';
import '../../../../../shared/widgets/components/dropdowns.dart';
import '../../../../../shared/widgets/components/inputs.dart';
import '../../../data/courses_models.dart';
import '../invite_students_dialog.dart';

class CourseStudentsTab extends ConsumerStatefulWidget {
  final MyCourseItem course;

  const CourseStudentsTab({super.key, required this.course});

  @override
  ConsumerState<CourseStudentsTab> createState() => _CourseStudentsTabState();
}

class _CourseStudentsTabState extends ConsumerState<CourseStudentsTab> {
  final TextEditingController _searchController = TextEditingController();

  List<_InviteRow> _invites = <_InviteRow>[];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filterLabel = 'All statuses';

  static const List<String> _filterLabels = <String>[
    'All statuses',
    'Accepted',
    'Pending',
    'Revoked',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CourseStudentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.id != widget.course.id) {
      _searchController.clear();
      _search = '';
      _filterLabel = 'All statuses';
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.course.isPrivate) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _invites = <_InviteRow>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get<Map<String, dynamic>>(
        Endpoints.courseInvitationsList(widget.course.id.toString()),
      );
      final data = res.data;
      final items = (data?['items'] as List?) ?? const <Object?>[];

      if (!mounted) return;
      setState(() {
        _invites = items
            .whereType<Map>()
            .map((e) => _InviteRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (e) {
      final failure = mapApiFailure(e);
      final msg = failure.message;
      final isEmptyOk = failure.statusCode == 404 ||
          failure.statusCode == 403 ||
          failure.statusCode == 409 ||
          msg.toLowerCase().contains('not found');

      if (!mounted) return;
      setState(() {
        _loading = false;
        _invites = <_InviteRow>[];
        _error = isEmptyOk ? null : msg;
      });
    }
  }

  String get _filterStatus {
    switch (_filterLabel) {
      case 'Accepted':
        return 'accepted';
      case 'Pending':
        return 'pending';
      case 'Revoked':
        return 'revoked';
      case 'Expired':
        return 'expired';
      default:
        return 'all';
    }
  }

  List<_InviteRow> get _filteredInvites {
    final query = _search.trim().toLowerCase();
    final status = _filterStatus;
    return _invites.where((invite) {
      final statusOk = status == 'all' || invite.status == status;
      final queryOk = query.isEmpty || invite.email.toLowerCase().contains(query);
      return statusOk && queryOk;
    }).toList();
  }

  int get _acceptedCount =>
      _invites.where((invite) => invite.status == 'accepted').length;
  int get _pendingCount =>
      _invites.where((invite) => invite.status == 'pending').length;

  Future<void> _openInviteDialog() async {
    final uploaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InviteStudentsDialog(courseId: widget.course.id),
    );
    if (uploaded ?? false) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.course.isPrivate) {
      return _PublicCourseMessage(course: widget.course);
    }

    final shown = _filteredInvites;

    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        children: [
          _StudentsHeader(
            course: widget.course,
            total: _invites.length,
            accepted: _acceptedCount,
            pending: _pendingCount,
            onInvite: _openInviteDialog,
            onRefresh: _loading ? null : _load,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _WorkspacePanel(
              searchController: _searchController,
              search: _search,
              filterLabel: _filterLabel,
              filterLabels: _filterLabels,
              loading: _loading,
              error: _error,
              total: _invites.length,
              shown: shown,
              onSearchChanged: (value) => setState(() => _search = value),
              onFilterChanged: (value) => setState(() => _filterLabel = value),
              onRetry: _load,
              onInvite: _openInviteDialog,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsHeader extends StatelessWidget {
  final MyCourseItem course;
  final int total;
  final int accepted;
  final int pending;
  final VoidCallback onInvite;
  final VoidCallback? onRefresh;

  const _StudentsHeader({
    required this.course,
    required this.total,
    required this.accepted,
    required this.pending,
    required this.onInvite,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5DCD), Color(0xFF168AE8), Color(0xFF19BCE8)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBlue.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Text(
                    'Private course access',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Student Workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${course.safeTitle} • invite-only enrollment management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.muted.copyWith(
                    color: Colors.white.withOpacity(0.86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _HeaderMetric(value: '$total', label: 'Invites'),
          const SizedBox(width: 10),
          _HeaderMetric(value: '$accepted', label: 'Accepted'),
          const SizedBox(width: 10),
          _HeaderMetric(value: '$pending', label: 'Pending'),
          const SizedBox(width: 16),
          _HeaderButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onPressed: onRefresh,
            outlined: true,
          ),
          const SizedBox(width: 10),
          _HeaderButton(
            icon: Icons.group_add_rounded,
            label: 'Invite students',
            onPressed: onInvite,
            outlined: false,
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.white.withOpacity(0.10) : Colors.white;
    final fg = outlined ? Colors.white : AppColors.primary;
    return SizedBox(
      height: 40,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null ? Colors.white.withOpacity(0.08) : bg,
          foregroundColor: onPressed == null ? Colors.white.withOpacity(0.45) : fg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(color: Colors.white.withOpacity(outlined ? 0.22 : 0)),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  final TextEditingController searchController;
  final String search;
  final String filterLabel;
  final List<String> filterLabels;
  final bool loading;
  final String? error;
  final int total;
  final List<_InviteRow> shown;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRetry;
  final VoidCallback onInvite;

  const _WorkspacePanel({
    required this.searchController,
    required this.search,
    required this.filterLabel,
    required this.filterLabels,
    required this.loading,
    required this.error,
    required this.total,
    required this.shown,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onRetry,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Toolbar(
            searchController: searchController,
            filterLabel: filterLabel,
            filterLabels: filterLabels,
            shownCount: shown.length,
            total: total,
            onSearchChanged: onSearchChanged,
            onFilterChanged: onFilterChanged,
          ),
          const Divider(height: 1),
          const _TableHeader(),
          Expanded(
            child: loading
                ? const _LoadingState()
                : error != null
                    ? _ErrorState(error: error!, onRetry: onRetry)
                    : shown.isEmpty
                        ? _EmptyState(
                            filtered: search.trim().isNotEmpty ||
                                filterLabel != 'All statuses',
                            onInvite: onInvite,
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: AppColors.border.withOpacity(0.72),
                            ),
                            itemBuilder: (context, index) {
                              return _InviteRowView(
                                invite: shown[index],
                                index: index + 1,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String filterLabel;
  final List<String> filterLabels;
  final int shownCount;
  final int total;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  const _Toolbar({
    required this.searchController,
    required this.filterLabel,
    required this.filterLabels,
    required this.shownCount,
    required this.total,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: FigmaUmSearch40(
              controller: searchController,
              hint: 'Search invited students by email...',
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          FigmaUmDropdown40(
            width: 156,
            value: filterLabel,
            items: filterLabels,
            onChanged: onFilterChanged,
          ),
          const SizedBox(width: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$shownCount of $total invites',
              style: AppTextStyles.mutedSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.mutedSmall.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.45,
      color: AppColors.textMuted,
    );
    return Container(
      height: 44,
      color: AppColors.headerBg.withOpacity(0.55),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text('#', style: style)),
          Expanded(flex: 5, child: Text('STUDENT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('INVITED', style: style)),
          Expanded(flex: 2, child: Text('ACCEPTED', style: style)),
        ],
      ),
    );
  }
}

class _InviteRowView extends StatelessWidget {
  final _InviteRow invite;
  final int index;

  const _InviteRowView({required this.invite, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: AppColors.cardBg,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _Avatar(email: invite.email, status: invite.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.email.isEmpty ? 'Unknown email' : invite.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        invite.status == 'accepted'
                            ? 'Enrollment confirmed'
                            : 'Waiting for student response',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mutedSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _StatusBadge(status: invite.status))),
          Expanded(flex: 2, child: Text(_formatDate(invite.createdAt), style: _cellStyle)),
          Expanded(
            flex: 2,
            child: Text(
              invite.acceptedAt == null ? '—' : _formatDate(invite.acceptedAt!),
              style: _cellStyle,
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle get _cellStyle => AppTextStyles.mutedSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      );
}

class _Avatar extends StatelessWidget {
  final String email;
  final String status;

  const _Avatar({required this.email, required this.status});

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == 'accepted';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isAccepted ? AppColors.successBg : AppColors.headerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccepted ? AppColors.greenBorder : AppColors.border,
        ),
      ),
      child: Text(
        email.trim().isEmpty ? '?' : email.trim()[0].toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isAccepted ? AppColors.successText : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    late final Color border;
    late final String label;

    switch (normalized) {
      case 'accepted':
        bg = AppColors.successBg;
        fg = AppColors.successText;
        border = AppColors.greenBorder;
        label = 'Accepted';
        break;
      case 'pending':
        bg = AppColors.warningSoftBg;
        fg = AppColors.warningText;
        border = AppColors.warningBorder;
        label = 'Pending';
        break;
      case 'revoked':
        bg = AppColors.dangerBg;
        fg = AppColors.dangerText;
        border = AppColors.dangerBorder;
        label = 'Revoked';
        break;
      case 'expired':
        bg = AppColors.headerBg;
        fg = AppColors.textMuted;
        border = AppColors.border;
        label = 'Expired';
        break;
      default:
        bg = AppColors.headerBg;
        fg = AppColors.textMuted;
        border = AppColors.border;
        label = status.isEmpty ? 'Unknown' : status;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 82, maxWidth: 110),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onInvite;

  const _EmptyState({required this.filtered, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                filtered ? Icons.search_off_rounded : Icons.group_add_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matching invitations' : 'No students invited yet',
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Clear search or change the status filter.'
                  : 'Upload an invitation sheet to start managing private course access.',
              style: AppTextStyles.muted.copyWith(height: 1.45),
              textAlign: TextAlign.center,
            ),
            if (!filtered) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onInvite,
                  icon: const Icon(Icons.group_add_rounded, size: 17),
                  label: const Text('Invite students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 38, color: AppColors.dangerText),
            const SizedBox(height: 14),
            Text('Failed to load invitations', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTextStyles.muted.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicCourseMessage extends StatelessWidget {
  final MyCourseItem course;

  const _PublicCourseMessage({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_rounded, color: AppColors.primary, size: 34),
            const SizedBox(height: 14),
            Text('Students tab is private-course only', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(
              '${course.safeTitle} is public. Students can join without invitation management.',
              style: AppTextStyles.muted.copyWith(height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteRow {
  final int id;
  final String email;
  final String status;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const _InviteRow({
    required this.id,
    required this.email,
    required this.status,
    this.acceptedAt,
    required this.createdAt,
  });

  factory _InviteRow.fromJson(Map<String, dynamic> json) {
    return _InviteRow(
      id: _asInt(json['id']),
      email: (json['invited_email'] ?? json['email'] ?? '').toString().trim(),
      status: (json['status'] ?? 'pending').toString().trim().toLowerCase(),
      acceptedAt: _parseDate(json['accepted_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '—';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

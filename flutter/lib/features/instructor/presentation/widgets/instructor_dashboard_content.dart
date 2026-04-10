import 'package:flutter/material.dart';
import 'package:learnova/shared/widgets/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Instructor Dashboard — Redesigned
//  Clean, modern SaaS aesthetic: crisp whites, strong typography,
//  colored accent strips, subtle depth. No generic gradients.
// ─────────────────────────────────────────────────────────────────────────────

class InstructorDashboardContent extends StatelessWidget {
  final String userName;
  const InstructorDashboardContent({
    super.key,
    this.userName = 'Professor Anderson',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final statsCols = w <= 600 ? 2 : 4;
      final isTwoColStacked = w <= 900;

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: w < 600 ? 16 : 32,
          vertical: 28,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                _Header(userName: userName),
                const SizedBox(height: 28),

                // ── Stats ────────────────────────────────────────────────────
                _StatsGrid(
                  columns: statsCols,
                  children: const [
                    _StatCard(
                      accentColor: Color(0xFF137FEC),
                      icon: Icons.folder_open_rounded,
                      trendText: '+2',
                      label: 'Uploaded Materials',
                      value: '12',
                      unit: 'Files',
                    ),
                    _StatCard(
                      accentColor: Color(0xFF8B5CF6),
                      icon: Icons.tag_rounded,
                      trendText: '+5',
                      label: 'Extracted Topics',
                      value: '45',
                      unit: 'Concepts',
                    ),
                    _StatCard(
                      accentColor: Color(0xFFF97316),
                      icon: Icons.format_list_bulleted_rounded,
                      trendText: '+20',
                      label: 'Generated Questions',
                      value: '120',
                      unit: 'Items',
                    ),
                    _StatCard(
                      accentColor: Color(0xFF10B981),
                      icon: Icons.groups_rounded,
                      trendText: '+3',
                      label: 'Active Students',
                      value: '85',
                      unit: 'Enrolled',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Body ─────────────────────────────────────────────────────
                isTwoColStacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RecentActivity(),
                          const SizedBox(height: 20),
                          _RightColumn(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _RecentActivity()),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: _RightColumn()),
                        ],
                      ),
              ],
            ),
          ),
        ),
      );
    },);
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String userName;
  const _Header({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('Home', style: TextStyle(fontSize: 11.5, color: AppColors.hint, fontWeight: FontWeight.w500)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 13, color: AppColors.hint),
                  SizedBox(width: 6),
                  Text('Dashboard', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back, $userName ',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textTitle,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Here's what's happening with your AI study assistant today.",
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        // Today's date badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 7),
              Text(
                _todayLabel(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTitle),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  const _StatsGrid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    return LayoutBuilder(builder: (ctx, c) {
      final colW = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children.map((e) => SizedBox(width: colW, child: e)).toList(),
      );
    },);
  }
}

class _StatCard extends StatefulWidget {
  final Color accentColor;
  final IconData icon;
  final String trendText;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.accentColor,
    required this.icon,
    required this.trendText,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _hovered ? widget.accentColor.withOpacity(0.35) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovered
              ? [
                  BoxShadow(color: widget.accentColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
                  const BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                ]
              : const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, size: 18, color: widget.accentColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFDF4),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text(widget.trendText,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(widget.label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(widget.value,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        letterSpacing: -0.5, color: widget.accentColor, height: 1,),),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(widget.unit,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Recent Activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle),),
            const Spacer(),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('View All',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: const Column(
            children: [
              _ActivityRow(
                accentColor: Color(0xFF8B5CF6),
                icon: Icons.auto_awesome_rounded,
                title: 'AI Processing Complete',
                sub: 'Extracted 15 topics from "Intro_to_Algorithms_Lec3.pdf".',
                time: '2 mins ago',
                isFirst: true,
              ),
              _ActivityRow(
                accentColor: Color(0xFF137FEC),
                icon: Icons.check_circle_outline_rounded,
                title: 'Quiz Published',
                sub: '"Midterm Practice Quiz" is now available to 85 students.',
                time: '1 hour ago',
              ),
              _ActivityRow(
                accentColor: Color(0xFFF97316),
                icon: Icons.warning_amber_rounded,
                title: 'Review Needed',
                sub: '3 questions for "Neural Networks" flagged for ambiguity.',
                time: '3 hrs ago',
              ),
              _ActivityRow(
                accentColor: Color(0xFF10B981),
                icon: Icons.person_add_alt_1_rounded,
                title: 'New Enrollment',
                sub: 'Student Sarah Jenkins joined the course.',
                time: '5 hrs ago',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatefulWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String sub;
  final String time;
  final bool isFirst;
  final bool isLast;

  const _ActivityRow({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.sub,
    required this.time,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFFAFBFC) : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(14) : Radius.zero,
            bottom: widget.isLast ? const Radius.circular(14) : Radius.zero,
          ),
        ),
        child: Column(
          children: [
            if (!widget.isFirst)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 16, color: widget.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle,),),
                        const SizedBox(height: 2),
                        Text(widget.sub,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted, height: 1.4,),),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.time,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textHint,),),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Right Column ─────────────────────────────────────────────────────────────

class _RightColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle),),
        const SizedBox(height: 10),
        _QuickActionsCard(),
        const SizedBox(height: 20),
        const Text('System Usage',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle),),
        const SizedBox(height: 10),
        const _UsageCard(),
      ],
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: const Column(
        children: [
          _ActionTile(
            icon: Icons.cloud_upload_outlined,
            iconColor: Color(0xFF137FEC),
            label: 'Upload Material',
            sub: 'Add PDFs, videos or docs',
            isFirst: true,
          ),
          _ActionTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: Color(0xFF8B5CF6),
            label: 'Generate Quiz',
            sub: 'AI-powered assessment',
          ),
          _ActionTile(
            icon: Icons.fact_check_outlined,
            iconColor: Color(0xFFF97316),
            label: 'Review Bank',
            sub: 'Approve AI questions',
          ),
          _ActionTile(
            icon: Icons.bar_chart_rounded,
            iconColor: Color(0xFF10B981),
            label: 'View Reports',
            sub: 'Student analytics',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final bool isFirst;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: Column(
          children: [
            if (!widget.isFirst)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _hovered ? const Color(0xFFFAFBFC) : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: widget.isFirst ? const Radius.circular(14) : Radius.zero,
                  bottom: widget.isLast ? const Radius.circular(14) : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 16, color: widget.iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle,),),
                        Text(widget.sub,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12,
                      color: _hovered ? AppColors.primary : AppColors.textHint,),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Usage Card ───────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  const _UsageCard();

  @override
  Widget build(BuildContext context) {
    const usedPct = 0.85;
    const barColor = usedPct >= 0.9
        ? Color(0xFFEF4444)
        : usedPct >= 0.75
            ? Color(0xFFF97316)
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Weekly Token Usage',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('85% Limit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('12,450',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.textTitle,),),
          const SizedBox(height: 4),
          const Text('tokens used this week',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 6, color: const Color(0xFFF1F5F9)),
                FractionallySizedBox(
                  widthFactor: usedPct,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MiniBarChart(),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const values = [0.34, 0.46, 1.0, 0.46, 0.34];
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
    const activeIndex = 2;
    const maxH = 52.0;

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final isActive = i == activeIndex;
          final barH = values[i] * maxH;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 60),
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isActive ? AppColors.primary : AppColors.textHint,),),
              ],
            ),
          );
        }),
      ),
    );
  }
}

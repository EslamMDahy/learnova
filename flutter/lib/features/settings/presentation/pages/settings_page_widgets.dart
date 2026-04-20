part of 'settings_page.dart';

class _StepPill extends StatelessWidget {
  final bool active;
  final String label;
  const _StepPill({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.primarySoft : const Color(0xFFF3F4F6);
    final border = active ? AppColors.primary : const Color(0xFFE5E7EB);
    final fg = active ? AppColors.primary : AppColors.muted;
    final weight = active ? FontWeight.w700 : FontWeight.w600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: weight),
      ),
    );
  }
}

// ============================================================================
// UI Widgets (unchanged - same as yours)
// ============================================================================

class _ProfileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String memberSince;
  final String lastLogin;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback? onUploadAvatar;

  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.memberSince,
    required this.lastLogin,
    this.avatarUrl,
    this.uploadingAvatar = false,
    this.onUploadAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 375,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            blurRadius: 2,
            offset: Offset(0, 1),
            color: AppColors.shadowSoft,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 25,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Avatar with upload overlay
                GestureDetector(
                  onTap: uploadingAvatar ? null : onUploadAvatar,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: AppColors.borderSoft,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6,
                              offset: Offset(0, 4),
                              color: Color(0x1A000000),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9999),
                          child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? Image.network(
                                  avatarUrl!,
                                  key: ValueKey(avatarUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 54,
                                    color: AppColors.muted,
                                  ),
                                )
                              : const Icon(Icons.person, size: 54, color: AppColors.muted),
                        ),
                      ),
                      if (uploadingAvatar)
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF137FEC),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 28 / 20,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Dot(color: AppColors.successDot),
                      SizedBox(width: 6),
                      Text(
                        'Active Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          height: 16 / 12,
                          color: AppColors.successText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 25,
            right: 25,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.only(top: 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0F2F4))),
              ),
              child: Column(
                children: [
                  _TwoColRow(left: 'Member since', right: memberSince),
                  const SizedBox(height: 8),
                  _TwoColRow(left: 'Last login', right: lastLogin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TwoColRow extends StatelessWidget {
  final String left;
  final String right;
  const _TwoColRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.muted,
              height: 20 / 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.title,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _NavCard({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 226,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            blurRadius: 2,
            offset: Offset(0, 1),
            color: AppColors.shadowSoft,
          ),
        ],
      ),
      child: Column(
        children: [
          _NavItem(
            selected: selectedIndex == 0,
            label: 'Personal Info',
            icon: Icons.person_outline,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            selected: selectedIndex == 1,
            label: 'Security',
            icon: Icons.lock_outline,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            selected: selectedIndex == 2,
            label: 'Preferences',
            icon: Icons.tune_rounded,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            selected: selectedIndex == 3,
            label: 'Notifications',
            icon: Icons.notifications_none_rounded,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primarySoft : Colors.transparent;
    final color = selected ? AppColors.primary : AppColors.muted;
    final weight = selected ? FontWeight.w700 : FontWeight.w500;

    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: bg,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: weight,
                fontSize: 14,
                height: 20 / 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  

}
class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  Widget _line({double h = 14, double? w}) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _card({double minH = 220}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              blurRadius: 2,
              offset: Offset(0, 1),
              color: AppColors.shadowSoft,
            ),
          ],
        ),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(h: 16, w: 180),
              const SizedBox(height: 10),
              _line(h: 12, w: 300),
              const SizedBox(height: 16),
              _line(h: 44),
              const SizedBox(height: 12),
              _line(h: 44),
              const SizedBox(height: 12),
              _line(h: 44),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(h: 22, w: 220),
                  const SizedBox(height: 8),
                  _line(w: 520),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                _line(h: 40, w: 120),
                const SizedBox(height: 10),
                _line(h: 40, w: 160),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Body skeleton
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _card(minH: 260),
                const SizedBox(height: 16),
                _card(minH: 260),
                const SizedBox(height: 16),
                _card(minH: 240),
                const SizedBox(height: 16),
                _card(minH: 280),
                const SizedBox(height: 16),
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

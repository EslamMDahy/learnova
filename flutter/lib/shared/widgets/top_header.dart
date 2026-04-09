import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_ui_components.dart';

class TopHeaderWidget extends StatelessWidget {
  final String searchHint;
  final String userName;
  final String userSubtitle;
  final String? avatarUrl;
  final int notificationsCount;

  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onNotificationsTap;

  final VoidCallback? onLogout;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;

  final VoidCallback? onMenuTap;
  final TextEditingController searchController;

  const TopHeaderWidget({
    super.key,
    required this.searchController,
    this.searchHint = 'Search topics, questions, or students...',
    this.userName = 'Alex Morgan',
    this.userSubtitle = 'Computer Science Dept.',
    this.avatarUrl,
    this.notificationsCount = 0,
    this.onSearchChanged,
    this.onNotificationsTap,
    this.onLogout,
    this.onProfile,
    this.onSettings,
    this.onMenuTap,
  });

  static const Color _bg = Colors.white;
  static const Color _bottomBorder = Color(0xFFEDF2F7);
  static const Color _divider = Color(0xFFE5E7EB);

  static const double _drawerBp = 1100;
  static const double _searchCollapseBp = 700;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    final isDrawerMode = w < _drawerBp;
    final collapseSearch = w < _searchCollapseBp;

    return Container(
      height: 73,
      padding: EdgeInsets.symmetric(
        horizontal: w < 900 ? 16 : 32,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _bottomBorder)),
      ),
      child: Row(
        children: [
          if (isDrawerMode) ...[
            _HeaderIconButton(
              icon: Icons.menu,
              tooltip: 'Open menu',
              onTap: onMenuTap ??
                  () {
                    Scaffold.of(context).openDrawer();
                  },
            ),
            const SizedBox(width: 12),
          ],

          if (!collapseSearch)
            SizedBox(
              width: w < 900 ? 240 : 320,
              height: 40,
              child: FigmaUmSearch40(
                controller: searchController,
                onChanged: onSearchChanged ?? (_) {},
              ),
            )
          else
            _HeaderIconButton(
              icon: Icons.search,
              tooltip: 'Search',
              onTap: () => _openSearchDialog(context),
            ),

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NotifIcon(
                hasBadge: notificationsCount > 0,
                onTap: onNotificationsTap,
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: _divider),
              const SizedBox(width: 16),

              _ModernHeaderProfileMenu(
                name: userName,
                subtitle: userSubtitle,
                avatarUrl: avatarUrl,
                onLogout: onLogout,
                onProfile: onProfile,
                onSettings: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSearchDialog(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final maxDialogWidth = math.min(520.0, math.max(280.0, w - 48.0));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Search'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxDialogWidth),
            child: TextField(
              controller: searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: onSearchChanged ?? (_) {},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: const Color(0xFF617589)),
      ),
    );
  }
}

class _NotifIcon extends StatelessWidget {
  final bool hasBadge;
  final VoidCallback? onTap;

  const _NotifIcon({
    required this.hasBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: onTap,
          icon: const Icon(
            Icons.notifications_none_rounded,
            size: 22,
            color: Color(0xFF617589),
          ),
        ),
        if (hasBadge)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// ✅ Modern menu trigger — no hover state needed
class _ModernHeaderProfileMenu extends StatefulWidget {
  final String name;
  final String subtitle;
  final String? avatarUrl;

  final VoidCallback? onLogout;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;

  const _ModernHeaderProfileMenu({
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.onLogout,
    this.onProfile,
    this.onSettings,
  });

  @override
  State<_ModernHeaderProfileMenu> createState() =>
      _ModernHeaderProfileMenuState();
}

class _ModernHeaderProfileMenuState extends State<_ModernHeaderProfileMenu> {
  final GlobalKey _anchorKey = GlobalKey();

  static const _nameColor = Color(0xFF0F172A);
  static const _subColor = Color(0xFF64748B);

  Future<void> _openMenu() async {
    final action = await showFigmaUmMenu<String>(
      context: context,
      anchorKey: _anchorKey,
      maxWidth: 220,
      entries: const [
        FigmaUmMenuEntry.item(
          value: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
        ),
        FigmaUmMenuEntry.item(
          value: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
        FigmaUmMenuEntry.divider(),
        FigmaUmMenuEntry.item(
          value: 'logout',
          label: 'Logout',
          icon: Icons.logout_rounded,
        ),
      ],
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'profile':
        widget.onProfile?.call();
        break;
      case 'settings':
        widget.onSettings?.call();
        break;
      case 'logout':
        widget.onLogout?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMenu,
      child: Container(
        key: _anchorKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1677FF),
                borderRadius: BorderRadius.circular(999),
              ),
              clipBehavior: Clip.antiAlias,
              child: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                  ? Image.network(
                      widget.avatarUrl!,
                      key: ValueKey(widget.avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 16, color: Colors.white),
                    )
                  : const Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _nameColor,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _subColor,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

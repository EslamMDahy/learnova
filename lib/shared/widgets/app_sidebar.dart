import 'app_ui_components.dart' as ui; 

typedef AppSidebarItem = ui.AppSidebarItem;

class AppSidebar extends ui.AppSidebar {
  const AppSidebar({
    super.key,
    required super.selectedIndex,
    required super.onItemSelected,
    required super.portalSubtitle,
    required super.mainItems,
    required super.bottomItems,
    super.brandTitle = 'Learnova',
    super.logoAssetPath = 'assets/logo.webp',
    super.onBrandTap,
  });
}

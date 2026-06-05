/// Design Tokens — re-export shim.
///
/// All canonical definitions live in lib/core/theme/app_theme.dart.
/// This file re-exports them so existing imports keep working unchanged.
library;
export '../../core/theme/app_theme.dart'
    show AppColors, AppSpacing, AppTheme, AppThemeRuntime, AppTextStyles, AppText;

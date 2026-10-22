import 'package:flutter/material.dart';

/// Màu lấy từ thiết kế Stitch (Obsidian Stream). Không hard-code màu trong màn hình,
/// hãy dùng AppColors.xxx hoặc Theme.of(context).
class AppColors {
  AppColors._();

  static const background = Color(0xFF131313);
  static const surface = Color(0xFF131313);
  static const surfaceLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceHigh = Color(0xFF2A2A2A);
  static const surfaceHighest = Color(0xFF353534);

  /// Màu nhấn chính: nút Đăng nhập, Tải lên, thanh tiến độ, tab đang chọn.
  static const accent = Color(0xFFFF5540);
  static const accentSoft = Color(0xFFFFB4A8);

  /// Link, chấm "có video mới", "Đánh dấu tất cả đã đọc".
  static const link = Color(0xFF9CCAFF);
  static const blueDot = Color(0xFF2295ED);

  static const textPrimary = Color(0xFFE5E2E1);
  static const textSecondary = Color(0xFFAAAAAA);
  static const divider = Color(0xFF353534);
  static const error = Color(0xFFFFB4AB);

  /// Chip đang chọn: nền trắng chữ đen.
  static const chipSelectedBg = Color(0xFFF1F1F1);
  static const chipSelectedFg = Color(0xFF0F0F0F);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.link,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentSoft),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48), // nút full-width: bọc SizedBox(width: double.infinity)
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.chipSelectedBg,
        side: BorderSide.none,
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        showCheckmark: false,
      ),
      dividerColor: AppColors.divider,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

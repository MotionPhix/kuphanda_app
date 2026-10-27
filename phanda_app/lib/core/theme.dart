import 'package:flutter/material.dart';

/// Kuphanda's visual identity.
///
/// The palette borrows from the Malawi flag — deep green, warm red and the
/// rising sun — but keeps the working surfaces paper-like so long reading
/// sessions stay comfortable on low-cost screens.
abstract final class AppColors {
  static const seed = Color(0xFF0F5B3A);
  static const green = Color(0xFF0F5B3A);
  static const greenDeep = Color(0xFF07301F);
  static const greenSoft = Color(0xFFDDEBE1);
  static const sun = Color(0xFFE3A33B);
  static const red = Color(0xFFA8322A);
  static const paper = Color(0xFFF7F4EC);
  static const paperDark = Color(0xFF14170F);
  static const ink = Color(0xFF1B1D18);
  static const muted = Color(0xFF5F655C);
}

abstract final class AppRadius {
  static const small = 10.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  ).copyWith(
    primary: isLight ? AppColors.green : const Color(0xFF87C9A6),
    onPrimary: isLight ? Colors.white : const Color(0xFF00391F),
    secondary: AppColors.sun,
    onSecondary: const Color(0xFF2A1B00),
    tertiary: isLight ? AppColors.red : const Color(0xFFFFB4A8),
    surface: isLight ? AppColors.paper : AppColors.paperDark,
    surfaceContainerLowest: isLight ? Colors.white : const Color(0xFF0C0F08),
    surfaceContainerLow: isLight ? const Color(0xFFFBF9F3) : const Color(0xFF181C13),
    surfaceContainer: isLight ? const Color(0xFFF1EDE2) : const Color(0xFF1D2118),
    surfaceContainerHigh: isLight ? const Color(0xFFE9E4D7) : const Color(0xFF262B20),
    onSurface: isLight ? AppColors.ink : const Color(0xFFE7E9E2),
    onSurfaceVariant: isLight ? AppColors.muted : const Color(0xFFAEB4A8),
    outlineVariant: isLight ? const Color(0xFFDCD6C7) : const Color(0xFF3A4033),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = base.textTheme
      .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )
      .copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.24),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.24),
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primary.withValues(alpha: 0.14),
      labelStyle: textTheme.labelMedium,
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        textStyle: textTheme.labelLarge,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isLight ? AppColors.ink : const Color(0xFFE7E9E2),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isLight ? Colors.white : AppColors.ink,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.12),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
  );
}

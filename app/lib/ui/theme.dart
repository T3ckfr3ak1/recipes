import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: dark ? const Color(0xFFE4B56A) : const Color(0xFF1E5C45),
    brightness: brightness,
  );
  final scheme = base.copyWith(
    surface: dark ? const Color(0xFF12100E) : const Color(0xFFF3EEE4),
    primary: dark ? const Color(0xFFE4B56A) : const Color(0xFF1E5C45),
    onPrimary: dark ? const Color(0xFF2A1C08) : Colors.white,
    primaryContainer: dark ? const Color(0xFF4A3518) : const Color(0xFFD5E8DF),
    onPrimaryContainer: dark
        ? const Color(0xFFFFE7C2)
        : const Color(0xFF0E2E22),
    secondary: dark ? const Color(0xFFE0B09A) : const Color(0xFF8C4A2F),
    onSecondary: dark ? const Color(0xFF2C1812) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF3D2A24)
        : const Color(0xFFF3DDD2),
    onSecondaryContainer: dark
        ? const Color(0xFFF6DDD3)
        : const Color(0xFF3A1E12),
    tertiary: dark ? const Color(0xFF9BB89A) : base.tertiary,
    onTertiary: dark ? const Color(0xFF102016) : base.onTertiary,
    tertiaryContainer: dark ? const Color(0xFF24362A) : base.tertiaryContainer,
    onTertiaryContainer: dark
        ? const Color(0xFFD5E8D4)
        : base.onTertiaryContainer,
    onSurface: dark ? const Color(0xFFF6F1E8) : const Color(0xFF1C1916),
    onSurfaceVariant: dark ? const Color(0xFFC9BBA8) : const Color(0xFF5C5348),
    outline: dark ? const Color(0xFF5C5348) : base.outline,
    outlineVariant: dark ? const Color(0xFF3A342C) : const Color(0xFFE0D6C8),
    surfaceContainerLowest: dark
        ? const Color(0xFF0C0B09)
        : const Color(0xFFFFFCF7),
    surfaceContainerLow: dark
        ? const Color(0xFF1A1714)
        : const Color(0xFFF7F2EA),
    surfaceContainer: dark ? const Color(0xFF1F1C18) : const Color(0xFFF3EEE4),
    surfaceContainerHigh: dark
        ? const Color(0xFF2A261F)
        : const Color(0xFFECE5D8),
    surfaceContainerHighest: dark
        ? const Color(0xFF352F28)
        : const Color(0xFFE4DCCE),
    inverseSurface: dark ? const Color(0xFFF6F1E8) : const Color(0xFF1C1916),
    onInverseSurface: dark ? const Color(0xFF1C1916) : const Color(0xFFF6F1E8),
    inversePrimary: dark ? const Color(0xFF7A5A24) : base.inversePrimary,
  );
  final card = dark ? const Color(0xFF221E1A) : const Color(0xFFFFFCF7);
  final radius = BorderRadius.circular(12);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    fontFamily: 'Noto Sans',
    visualDensity: VisualDensity.compact,
    splashColor: scheme.primary.withValues(alpha: 0.12),
    highlightColor: scheme.primary.withValues(alpha: 0.08),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.28),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
  );
}

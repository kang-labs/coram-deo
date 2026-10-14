import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_themes.dart';

/// [AppPalette] 하나로 앱 전체 [ThemeData]를 만듭니다.
class AppTheme {
  AppTheme._();

  static const radius = 24.0;

  static final _cache = <AppThemeId, ThemeData>{};

  /// 테마별 ThemeData는 한 번만 만들고 재사용합니다.
  static ThemeData of(AppThemeId id) => _cache[id] ??= build(id.palette);

  static ThemeData build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: p.brightness).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.onPrimarySoft,
      secondary: p.accent,
      // M3 선택 표시(칩 등)는 secondaryContainer를 써서, 주 색과 어긋나지 않게 맞춥니다.
      secondaryContainer: p.primarySoft,
      onSecondaryContainer: p.onPrimarySoft,
      tertiary: p.warm,
      tertiaryContainer: p.warmSoft,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSoft,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceMuted,
      surfaceContainerHigh: p.surfaceMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.hint,
      outlineVariant: p.line,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: p.brightness);
    final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const pill = StadiumBorder();
    const buttonSize = Size(64, 52);
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
    Color pick(Set<WidgetState> s, Color on, Color off) => s.contains(WidgetState.selected) ? on : off;

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: p.inkSoft),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(color: p.inkSoft),
      ),
      iconTheme: IconThemeData(color: p.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle(p),
        titleTextStyle: TextStyle(color: p.ink, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: p.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: pill, textStyle: buttonText, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          textStyle: buttonText,
          foregroundColor: p.primary,
          side: BorderSide(color: p.line, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: pill,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: TextStyle(color: p.inkSoft),
        floatingLabelStyle: TextStyle(color: p.primary, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: p.hint),
        helperStyle: TextStyle(color: p.inkSoft),
        counterStyle: TextStyle(color: p.inkSoft),
        border: field(p.line, 1.5),
        enabledBorder: field(p.line, 1.5),
        focusedBorder: field(p.primary, 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: p.primarySoft,
        indicatorShape: pill,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: pick(s, p.primary, p.inkSoft),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: pick(s, p.primary, p.inkSoft))),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.onPrimary,
        unselectedLabelColor: p.inkSoft,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(100)),
        splashBorderRadius: BorderRadius.circular(100),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        iconColor: p.primary,
        titleTextStyle: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: p.inkSoft, fontSize: 13),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: p.primary,
        collapsedIconColor: p.inkSoft,
        textColor: p.ink,
        collapsedTextColor: p.ink,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primarySoft,
        side: BorderSide(color: p.line),
        shape: pill,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.hint,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
        titleTextStyle: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: p.inkSoft, fontSize: 15, height: 1.45),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceMuted : p.ink,
        contentTextStyle: TextStyle(color: p.isDark ? p.ink : p.surface, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.primarySoft),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
      ),
    );
  }

  /// 상태바·내비게이션바 아이콘 색을 테마 밝기에 맞춥니다.
  static SystemUiOverlayStyle overlayStyle(AppPalette p) {
    final base = p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: p.surface,
      systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      // 버튼식 하단 바에 시스템이 밝은 띠를 덧씌우지 않게 (어두운 테마에서 튀어 보임)
      systemNavigationBarContrastEnforced: false,
    );
  }
}

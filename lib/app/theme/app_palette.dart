import 'package:flutter/material.dart';

/// 테마 하나의 모든 색. 화면에서는 색을 직접 쓰지 말고 `context.palette`로 읽습니다.
///
/// 새 색이 필요하면 여기에 필드를 추가하고, [AppThemeId]의 모든 팔레트와 [lerp]에 값을 채웁니다.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.accent,
    required this.accentSoft,
    required this.warm,
    required this.warmSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSoft,
    required this.hint,
    required this.line,
    required this.shadow,
  });

  final Brightness brightness;

  /// 주 색 (버튼, 선택 표시, 체크한 날)
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;

  /// 보조 색
  final Color accent;
  final Color accentSoft;

  /// 따뜻한 강조 (지각)
  final Color warm;
  final Color warmSoft;

  /// 했어요 (○)
  final Color success;
  final Color successSoft;

  /// 안 했어요 (X), 감점
  final Color danger;
  final Color dangerSoft;

  final Color background;
  final Color surface;

  /// 눈에 덜 띄는 칸 (휴강 주, 표 머리)
  final Color surfaceMuted;

  /// 본문 글자
  final Color ink;

  /// 보조 글자
  final Color inkSoft;
  final Color hint;
  final Color line;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  List<BoxShadow> get softShadow => [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimarySoft: l(onPrimarySoft, other.onPrimarySoft),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      warm: l(warm, other.warm),
      warmSoft: l(warmSoft, other.warmSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      hint: l(hint, other.hint),
      line: l(line, other.line),
      shadow: l(shadow, other.shadow),
    );
  }

  /// 테마 확장 규약상 필요하지만 앱에서는 팔레트를 통째로 바꿔 씁니다.
  @override
  AppPalette copyWith() => this;
}

extension AppPaletteContext on BuildContext {
  /// 현재 테마의 색. `Theme.of`를 쓰므로 테마가 바뀌면 자동으로 다시 그려집니다.
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

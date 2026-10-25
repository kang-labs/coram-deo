import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 고를 수 있는 테마 목록. 새 테마는 여기에 값 하나 + 팔레트 하나만 추가하면 됩니다.
///
/// [name]은 기기에 저장되는 키라서, 이미 출시한 테마의 이름은 바꾸지 마세요.
enum AppThemeId {
  slate('슬레이트', '차분한 네이비와 밝은 회색 (기본)', _slate),
  blossom('블러썸', '로즈 핑크와 아이보리', _blossom),
  milk('밀크', '깨끗하고 밝은 화이트', _milk),
  lavender('라벤더', '몽글몽글 연보라', _lavender),
  mint('민트', '산뜻한 민트와 하늘', _mint),
  midnight('미드나잇', '차분한 네이비 다크', _midnight),
  dark('다크', '검은 바탕에 회색 글자, 밤에 보기 편해요', _dark);

  const AppThemeId(this.label, this.description, this.palette);

  final String label;
  final String description;
  final AppPalette palette;

  /// 테마를 고른 적 없는 사람(저장값 없음)은 이 테마로 보여요.
  static const fallback = AppThemeId.slate;

  static AppThemeId fromName(String? name) {
    for (final id in values) {
      if (id.name == name) return id;
    }
    return fallback;
  }
}

/// 기본: 깊은 네이비 + 밝은 회색 바탕, 흰 카드, 옅은 회색 선. ○·X·지각 색은 채도를 낮춰 차분하게.
const _slate = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF2F3E5C),
  onPrimary: Colors.white,
  primarySoft: Color(0xFFE5E9F0),
  onPrimarySoft: Color(0xFF1F2A40),
  accent: Color(0xFF5E7A99),
  accentSoft: Color(0xFFE8EDF3),
  warm: Color(0xFFB07D2E),
  warmSoft: Color(0xFFF5EEDF),
  success: Color(0xFF3E8467),
  successSoft: Color(0xFFE2EFE8),
  danger: Color(0xFFBA4F4B),
  dangerSoft: Color(0xFFF6E4E3),
  background: Color(0xFFF6F7F9),
  surface: Colors.white,
  surfaceMuted: Color(0xFFEEF0F3),
  ink: Color(0xFF1F2633),
  inkSoft: Color(0xFF687083),
  hint: Color(0xFFB3B9C4),
  line: Color(0xFFE2E5EA),
  shadow: Color(0x0A1F2A40),
);

const _blossom = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFFEC7A95),
  onPrimary: Colors.white,
  primarySoft: Color(0xFFFCE4EA),
  onPrimarySoft: Color(0xFF8A2F48),
  accent: Color(0xFF8B6FD6),
  accentSoft: Color(0xFFEFE9FC),
  warm: Color(0xFFE5834F),
  warmSoft: Color(0xFFFFEDE2),
  success: Color(0xFF2E9C76),
  successSoft: Color(0xFFE2F5EE),
  danger: Color(0xFFE0566C),
  dangerSoft: Color(0xFFFDE6EA),
  background: Color(0xFFFFF8F6),
  surface: Colors.white,
  surfaceMuted: Color(0xFFF4EFF2),
  ink: Color(0xFF3B3240),
  inkSoft: Color(0xFF8C8090),
  hint: Color(0xFFC4B8C2),
  line: Color(0xFFF3E6E8),
  shadow: Color(0x14C26A82),
);

const _milk = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF5B7CFA),
  onPrimary: Colors.white,
  primarySoft: Color(0xFFE6ECFF),
  onPrimarySoft: Color(0xFF2B45B0),
  accent: Color(0xFFF0709A),
  accentSoft: Color(0xFFFDE8EF),
  warm: Color(0xFFEE9A2E),
  warmSoft: Color(0xFFFFF2DE),
  success: Color(0xFF22A06B),
  successSoft: Color(0xFFE1F5EC),
  danger: Color(0xFFE5484D),
  dangerSoft: Color(0xFFFDE7E8),
  background: Color(0xFFF6F7FB),
  surface: Colors.white,
  surfaceMuted: Color(0xFFEFF1F6),
  ink: Color(0xFF1F2333),
  inkSoft: Color(0xFF7A8094),
  hint: Color(0xFFB8BDCC),
  line: Color(0xFFE8EBF2),
  shadow: Color(0x0F3B4A7A),
);

const _lavender = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF9B7BEA),
  onPrimary: Colors.white,
  primarySoft: Color(0xFFEFE8FD),
  onPrimarySoft: Color(0xFF5634A8),
  accent: Color(0xFFE98AB8),
  accentSoft: Color(0xFFFCE8F2),
  warm: Color(0xFFE8935A),
  warmSoft: Color(0xFFFDEEE3),
  success: Color(0xFF3FAE8C),
  successSoft: Color(0xFFE2F4EE),
  danger: Color(0xFFE0566C),
  dangerSoft: Color(0xFFFDE6EA),
  background: Color(0xFFF9F7FF),
  surface: Colors.white,
  surfaceMuted: Color(0xFFF1EEF8),
  ink: Color(0xFF332D45),
  inkSoft: Color(0xFF8A84A0),
  hint: Color(0xFFC3BED4),
  line: Color(0xFFEAE5F6),
  shadow: Color(0x149B7BEA),
);

const _mint = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF2FB38E),
  onPrimary: Colors.white,
  primarySoft: Color(0xFFDDF5EC),
  onPrimarySoft: Color(0xFF14694F),
  accent: Color(0xFF4B9BE8),
  accentSoft: Color(0xFFE2F0FD),
  warm: Color(0xFFF08A5D),
  warmSoft: Color(0xFFFEEDE4),
  success: Color(0xFF2E8FD0),
  successSoft: Color(0xFFE2F0FD),
  danger: Color(0xFFE0566C),
  dangerSoft: Color(0xFFFDE6EA),
  background: Color(0xFFF3FBF8),
  surface: Colors.white,
  surfaceMuted: Color(0xFFEAF4F0),
  ink: Color(0xFF203A33),
  inkSoft: Color(0xFF6F8A82),
  hint: Color(0xFFB3C9C2),
  line: Color(0xFFDDEFE8),
  shadow: Color(0x142FB38E),
);

const _midnight = AppPalette(
  brightness: Brightness.dark,
  primary: Color(0xFF8AB4FF),
  onPrimary: Color(0xFF0E1A33),
  primarySoft: Color(0xFF1F2A40),
  onPrimarySoft: Color(0xFFC4D8FF),
  accent: Color(0xFF7FD1C7),
  accentSoft: Color(0xFF1A302E),
  warm: Color(0xFFF2B66D),
  warmSoft: Color(0xFF352A1C),
  success: Color(0xFF6FD3A0),
  successSoft: Color(0xFF18302A),
  danger: Color(0xFFFF7A85),
  dangerSoft: Color(0xFF3A1F25),
  background: Color(0xFF12151B),
  surface: Color(0xFF1C2028),
  surfaceMuted: Color(0xFF262B35),
  ink: Color(0xFFECEFF4),
  inkSoft: Color(0xFF9AA3B2),
  hint: Color(0xFF5F6878),
  line: Color(0xFF2A303B),
  shadow: Color(0x40000000),
);

/// 다크: 거의 검은 바탕(OLED 폰은 배터리도 아껴요) + 차분한 회색 카드, 강조는 부드러운 하늘색.
/// 글자 대비는 밝은 회백색으로 충분히(바탕 대비 약 15:1), ○·X·지각 색은 어두운 바탕에서 눈부시지 않게 채도를 낮춰요.
const _dark = AppPalette(
  brightness: Brightness.dark,
  primary: Color(0xFF9DB7DD),
  onPrimary: Color(0xFF111418),
  primarySoft: Color(0xFF252A31),
  onPrimarySoft: Color(0xFFD6E2F2),
  accent: Color(0xFFA7B4C2),
  accentSoft: Color(0xFF23272D),
  warm: Color(0xFFE0B47A),
  warmSoft: Color(0xFF2E2820),
  success: Color(0xFF7CC9A1),
  successSoft: Color(0xFF1C2A23),
  danger: Color(0xFFE88A8A),
  dangerSoft: Color(0xFF331F21),
  background: Color(0xFF0B0C0E),
  surface: Color(0xFF17191C),
  surfaceMuted: Color(0xFF212429),
  ink: Color(0xFFE8EAED),
  inkSoft: Color(0xFF9AA0A8),
  hint: Color(0xFF5C6168),
  line: Color(0xFF2A2D32),
  shadow: Color(0x66000000),
);

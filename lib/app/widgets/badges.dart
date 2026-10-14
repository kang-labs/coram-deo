import 'package:flutter/material.dart';

import '../theme.dart';

/// 아이콘 뱃지·강조 영역의 색 조합. 실제 색은 테마 팔레트에서 정해집니다.
enum Tone {
  primary,
  accent,
  warm,
  success,
  danger,
  neutral;

  /// (전경색, 배경색)
  (Color, Color) colors(AppPalette p) => switch (this) {
    Tone.primary => (p.primary, p.primarySoft),
    Tone.accent => (p.accent, p.accentSoft),
    Tone.warm => (p.warm, p.warmSoft),
    Tone.success => (p.success, p.successSoft),
    Tone.danger => (p.danger, p.dangerSoft),
    Tone.neutral => (p.inkSoft, p.surfaceMuted),
  };
}

/// 파스텔 배경 위에 아이콘을 올린 둥근 뱃지
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.icon, this.tone = Tone.primary, this.size = 44});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.palette);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.36)),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// 둥근 작은 배지 (휴강, 숨김 등)
class TinyBadge extends StatelessWidget {
  const TinyBadge(this.label, {super.key, this.tone = Tone.primary});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 보조 설명 글씨 (흐린 색 본문)
class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key, this.textAlign, this.style});

  final String text;
  final TextAlign? textAlign;

  /// 크기 등 추가로 덮어쓸 스타일 (색은 무시됩니다)
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return Text(
      text,
      textAlign: textAlign,
      style: base.merge(style).copyWith(color: context.palette.inkSoft),
    );
  }
}

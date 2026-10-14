import 'package:flutter/material.dart';

import '../theme.dart';
import 'badges.dart';

/// 테두리 없이 그림자만 살짝 있는 둥근 카드
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 기본값은 테마의 카드 색
  final Color? color;

  /// 있으면 테두리를 그립니다 (이번 주 강조 등)
  final Color? borderColor;

  /// 카드 전체를 누를 수 있게 할 때
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const radius = BorderRadius.all(Radius.circular(AppTheme.radius));
    final content = Padding(padding: padding, child: child);
    // 그림자는 바깥 상자가, 배경은 Material/Ink가 그려서 InkWell 물결이 보이게 합니다.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: p.softShadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? p.surface,
            borderRadius: radius,
            // 옅은 테두리로 카드 경계를 또렷하게, 강조할 때는 굵은 색 테두리
            border: borderColor == null ? Border.all(color: p.line) : Border.all(color: borderColor!, width: 2),
          ),
          child: onTap == null ? content : InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// 굵은 제목 + 아이콘 뱃지 한 줄 (카드 머리말)
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.icon, required this.title, this.tone = Tone.primary, this.trailing});

  final IconData icon;
  final String title;
  final Tone tone;

  /// 제목 오른쪽 끝
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBubble(icon: icon, tone: tone, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    );
  }
}

/// 아직 내용이 없을 때 보여주는 안내
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;

  /// 안내 아래 버튼
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.primarySoft, p.accentSoft],
                ),
              ),
              child: Icon(icon, size: 44, color: p.primary),
            ),
            const SizedBox(height: 24),
            Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: p.inkSoft),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

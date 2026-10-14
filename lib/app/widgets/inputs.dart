import 'package:flutter/material.dart';

import '../theme.dart';
import 'badges.dart';

/// 시트·편집 화면의 입력 묶음 위에 붙는 작은 제목 (아래 간격 8)
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// 선택지 하나 (값, 표시 글자, 골랐을 때 색)
typedef PillOption<T> = ({T value, String label, Tone tone});

/// 여러 개 중 하나를 고르는 알약 줄. 애니메이션 없이 바로 바뀝니다.
/// 고른 알약은 옅은 색 바탕 + 진한 글자, 안 고른 알약은 테두리만 있는 흐린 글자예요.
/// [clearable]이면 고른 알약을 다시 누를 때 null(비움)로 돌아갑니다.
class SelectPills<T> extends StatelessWidget {
  const SelectPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.clearable = false,
    this.minWidth = 0,
    this.glyph,
  });

  /// 순서대로의 선택지
  final List<PillOption<T>> options;
  final T? selected;

  /// null이면 고를 수 없음(흐리게)
  final ValueChanged<T?>? onSelected;
  final bool clearable;

  /// 알약 최소 폭 (○ X 같은 한 글자 알약을 누르기 쉽게)
  final double minWidth;

  /// 글자 대신 그릴 표시 (값, 색, 골랐는지). 없으면 [PillOption.label] 글자.
  final Widget Function(T value, Color color, bool selected)? glyph;

  /// 글자 하나짜리 선택지를 만드는 도우미 (색은 기본 주 색)
  static List<PillOption<T>> simple<T>(Map<T, String> map) => [
    for (final e in map.entries) (value: e.key, label: e.value, tone: Tone.primary),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onSelected != null;
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final o in options) _pill(p, o, enabled)]);
  }

  Widget _pill(AppPalette p, PillOption<T> o, bool enabled) {
    final on = o.value == selected;
    final (fg, soft) = o.tone.colors(p);
    final color = on ? fg : (enabled ? p.inkSoft : p.hint);
    return Semantics(
      button: true,
      selected: on,
      enabled: enabled,
      label: o.label,
      excludeSemantics: glyph != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !enabled ? null : () => onSelected!(clearable && on ? null : o.value),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? soft : (enabled ? p.surface : p.surfaceMuted),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: on ? fg.withValues(alpha: 0.55) : p.line, width: 1.5),
          ),
          // 가운데 정렬하되 알약 폭은 글자만큼만 (Container alignment는 Wrap 안에서 한 줄을 다 차지해요)
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: glyph != null
                ? glyph!(o.value, color, on)
                : Text(
                    o.label,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 알약 모양 드롭다운. [options]는 값 → 표시 이름(순서대로).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = false,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T>? onChanged;

  /// 주어진 폭을 다 쓰고 긴 글자는 …로 줄여요 (좁은 화면)
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.onPrimarySoft);
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(100)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: expand,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: p.surface,
          icon: Icon(Icons.expand_more_rounded, size: 20, color: p.inkSoft),
          style: style.copyWith(color: p.ink),
          selectedItemBuilder: (_) => [
            for (final label in options.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: style, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
          ],
          items: [
            for (final e in options.entries)
              DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
          ],
          onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
        ),
      ),
    );
  }
}

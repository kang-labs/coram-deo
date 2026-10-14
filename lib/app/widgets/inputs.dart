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
/// [clearable]이면 고른 알약을 다시 누를 때 null(비움)로 돌아갑니다.
class SelectPills<T> extends StatelessWidget {
  const SelectPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.clearable = false,
    this.minWidth = 0,
  });

  /// 순서대로의 선택지
  final List<PillOption<T>> options;
  final T? selected;

  /// null이면 고를 수 없음(흐리게)
  final ValueChanged<T?>? onSelected;
  final bool clearable;

  /// 알약 최소 폭 (○ X 같은 한 글자 알약을 누르기 쉽게)
  final double minWidth;

  /// 글자 하나짜리 선택지를 만드는 도우미 (색은 기본 주 색)
  static List<PillOption<T>> simple<T>(Map<T, String> map) => [
    for (final e in map.entries) (value: e.key, label: e.value, tone: Tone.primary),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onSelected != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          Builder(
            builder: (context) {
              final on = o.value == selected;
              final (fg, _) = o.tone.colors(p);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: !enabled ? null : () => onSelected!(clearable && on ? null : o.value),
                child: Container(
                  constraints: BoxConstraints(minWidth: minWidth, minHeight: 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? fg : p.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: on ? fg : p.line, width: 1.5),
                  ),
                  child: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: on ? p.onPrimary : (enabled ? p.inkSoft : p.hint),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 알약 모양 드롭다운. [options]는 값 → 표시 이름(순서대로).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({super.key, required this.options, required this.value, required this.onChanged});

  final Map<T, String> options;
  final T value;
  final ValueChanged<T>? onChanged;

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
          borderRadius: BorderRadius.circular(18),
          dropdownColor: p.surface,
          icon: Icon(Icons.expand_more_rounded, size: 20, color: p.inkSoft),
          style: style.copyWith(color: p.ink),
          selectedItemBuilder: (_) => [
            for (final label in options.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: style),
              ),
          ],
          items: [for (final e in options.entries) DropdownMenuItem<T>(value: e.key, child: Text(e.value))],
          onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
        ),
      ),
    );
  }
}

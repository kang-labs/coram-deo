import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../record/logic/part_display.dart';
import '../../record/logic/record_providers.dart';
import '../../record/ui/mark_glyph.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';

/// 주별 보기의 칸 값 하나를 크게 (멀리서도 보이게). 칸 값만 watch 해요.
///
/// - ○ / X / · / 지: 직접 그린 표시(같은 크기 상자). 사유는 값 아래 작은 글씨
/// - 성경·큐티·기도: 한 날 수 (예: 5 /7)
/// - 새벽기도: 점수 (2회) — 휴강·시작 전 주는 비움
/// - 비었으면 흐린 '–'
class BigValue extends ConsumerWidget {
  const BigValue({
    super.key,
    required this.part,
    required this.week,
    required this.itemId,
    required this.classDate,
    required this.off,
    this.subLabel,
  });

  final PartDef part;

  /// 주차 (1부터)
  final int week;
  final String itemId;
  final DateTime? classDate;
  final bool off;

  static const valueSize = 26.0;

  /// ○·X·· ·지 표시 상자 (모두 같은 크기 → 줄마다 위치가 맞아요)
  static const markBox = 36.0;

  /// 여러 칸 항목의 칸 이름 (출석, 후기 …). 칸 하나면 null.
  final String? subLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final entry = ref.watch(courseRecordProvider.select((r) => r.entry(week, itemId, part.id)));
    final small = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.inkSoft);
    final core = _core(context, ref, entry.value, small);
    final row = subLabel == null
        ? core
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subLabel!, style: small.copyWith(fontSize: 14)),
              const SizedBox(width: 8),
              core,
            ],
          );
    final note = part.dotReason ? entry.note : null;
    if (note == null) return row;
    // 사유는 값 아래 따로 한 줄(최대 두 줄), 오른쪽 정렬
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        row,
        Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: small),
      ],
    );
  }

  Widget _core(BuildContext context, WidgetRef ref, Object? value, TextStyle small) {
    final p = context.palette;
    TextStyle big(Color color) =>
        TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800, height: 1.1, color: color);
    Widget box(Widget child) => SizedBox(
      width: markBox,
      height: markBox,
      child: Center(child: child),
    );
    final dash = box(
      Text(
        '–',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.hint),
      ),
    );

    if (!part.type.isDaily) {
      final mark = MarkValue.fromCode(value);
      if (mark == null) return dash;
      return box(MarkGlyph(value: mark, color: markTone(mark).colors(p).$1, size: 30));
    }

    final mask = value is int ? value : 0;
    final count = countDays(mask);
    if (part.type == PartType.dawn) {
      final started = classDate != null && ref.watch(todayProvider.select((t) => weekStarted(classDate!, t)));
      if (!isScoredWeek(started: started, off: off)) {
        return count == 0 ? dash : Text('$count회', style: small.copyWith(fontSize: 16));
      }
      final score = dawnScore(count);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(scoreText(score), style: big(score < 0 ? p.danger : p.ink)),
          const SizedBox(width: 4),
          Text('($count회)', style: small),
        ],
      );
    }
    if (count == 0) return dash;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$count', style: big(p.ink)),
        Text(' /$daysPerWeek', style: small),
      ],
    );
  }
}

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
/// - ○ / X / · / 지: 직접 그린 표시. ·는 옆에 사유
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
  });

  final PartDef part;

  /// 주차 (1부터)
  final int week;
  final String itemId;
  final DateTime? classDate;
  final bool off;

  static const valueSize = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final entry = ref.watch(courseRecordProvider.select((r) => r.entry(week, itemId, part.id)));
    final dash = Text(
      '–',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.hint),
    );
    TextStyle big(Color color) =>
        TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800, height: 1.1, color: color);
    final small = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.inkSoft);

    if (!part.type.isDaily) {
      final mark = MarkValue.fromCode(entry.value);
      if (mark == null) return dash;
      final glyph = MarkGlyph(value: mark, color: markTone(mark).colors(p).$1, size: 30);
      final note = entry.note;
      if (note == null) return glyph;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          const SizedBox(width: 6),
          // 좁으면 사유 글자가 줄어든 칸 안에서 …로
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
            ),
          ),
        ],
      );
    }

    final mask = entry.value is int ? entry.value as int : 0;
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

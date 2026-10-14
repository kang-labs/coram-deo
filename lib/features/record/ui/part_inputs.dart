import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';
import '../logic/part_display.dart';
import '../logic/record_providers.dart';
import 'mark_glyph.dart';

/// 한 칸이 어느 주·항목·칸인지
typedef PartRef = ({int week, String itemId, String partId});

/// 체크 항목 카드 하나. 칸 종류마다 공통 입력([PartInput])으로 그려서 항목별 코드가 없어요.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.week, required this.classDate});

  final ItemDef item;

  /// 주차 (1부터)
  final int week;
  final DateTime classDate;

  @override
  Widget build(BuildContext context) {
    final single = item.parts.length == 1;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < item.parts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            PartInput(
              title: single ? item.label : null,
              groupTitle: !single && i == 0 ? item.label : null,
              part: item.parts[i],
              ref: (week: week, itemId: item.id, partId: item.parts[i].id),
              classDate: classDate,
            ),
          ],
        ],
      ),
    );
  }
}

/// 칸 하나의 입력. 종류([PartType])에 따라 고르는 알약 또는 요일 7칸.
class PartInput extends StatelessWidget {
  const PartInput({
    super.key,
    required this.part,
    required this.ref,
    required this.classDate,
    this.title,
    this.groupTitle,
  });

  final PartDef part;
  final PartRef ref;
  final DateTime classDate;

  /// 칸이 하나뿐인 항목: 항목 이름을 제목으로
  final String? title;

  /// 칸이 여러 개인 항목의 첫 칸 위에 붙는 항목 이름
  final String? groupTitle;

  @override
  Widget build(BuildContext context) {
    final label = title ?? part.label;
    final labelStyle = title != null
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)
        : const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    final input = part.type.isDaily
        ? _DailyInput(
            part: part,
            pref: ref,
            classDate: classDate,
            label: Text(label, style: labelStyle),
          )
        : _ChoiceInput(
            part: part,
            pref: ref,
            classDate: classDate,
            label: Text(label, style: labelStyle),
          );
    if (groupTitle == null) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(groupTitle!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        input,
      ],
    );
  }
}

/// ○ / X / ·, ○ / X / 지각 고르기 (다시 누르면 비움). 그 주가 시작 전이면 고를 수 없어요.
class _ChoiceInput extends ConsumerWidget {
  const _ChoiceInput({required this.part, required this.pref, required this.classDate, required this.label});

  final PartDef part;
  final PartRef pref;
  final DateTime classDate;
  final Widget label;

  /// 사유 적기 창. 취소하면 null.
  Future<String?> _askNote(BuildContext context, String? current) => showTextInputDialog(
    context,
    title: '사유',
    label: '왜 ·인지 적어 주세요',
    hint: '예: 휴일',
    initialValue: current ?? '',
    maxLength: noteMaxLength,
  );

  Future<void> _select(BuildContext context, WidgetRef ref, String? code, String? note) async {
    final notifier = ref.read(courseRecordProvider.notifier);
    final mark = MarkValue.fromCode(code);
    if (mark != null && part.needsNote(mark)) {
      // 사유는 꼭 적어요. 취소하면 바꾸지 않아요.
      final n = await _askNote(context, note);
      if (n == null || n.trim().isEmpty) return;
      notifier.setValue(pref.week, pref.itemId, pref.partId, code, note: n);
    } else {
      notifier.setValue(pref.week, pref.itemId, pref.partId, code);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(courseRecordProvider.select((r) => r.entry(pref.week, pref.itemId, pref.partId)));
    final value = entry.value;
    final note = entry.note;
    final started = ref.watch(todayProvider.select((t) => weekStarted(classDate, t)));
    final row = Row(
      children: [
        Expanded(child: label),
        SelectPills<String>(
          // '지각'도 ○·X와 같은 폭이 되게 넉넉히 → 줄마다 버튼 위치가 맞아요
          minWidth: 64,
          clearable: true,
          options: [for (final v in part.type.choices) (value: v.code, label: v.buttonLabel, tone: markTone(v))],
          glyph: (code, color, on) => MarkGlyph(
            value: MarkValue.fromCode(code)!,
            label: MarkValue.fromCode(code)!.buttonLabel,
            // 안 고른 표시는 흐리게
            color: on ? color : context.palette.hint,
          ),
          selected: value is String ? value : null,
          onSelected: !started ? null : (v) => _select(context, ref, v, note),
        ),
      ],
    );
    // 사유를 안 받는 칸이면 예전 사유가 남아 있어도 숨겨요
    if (note == null || !part.dotReason) return row;
    // 사유: 줄 아래 작은 글씨, 누르면 고치기
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _select(context, ref, value as String?, note),
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 16, color: context.palette.inkSoft),
                const SizedBox(width: 4),
                Expanded(child: MutedText('사유: $note', style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 사유 최대 글자 수
const noteMaxLength = 60;

/// 요일 7칸 (요일 + 날짜). 오늘은 테두리, 아직 오지 않은 날은 누를 수 없어요. 옆에 합계.
class _DailyInput extends ConsumerWidget {
  const _DailyInput({required this.part, required this.pref, required this.classDate, required this.label});

  final PartDef part;
  final PartRef pref;
  final DateTime classDate;
  final Widget label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mask = ref.watch(courseRecordProvider.select((r) => r.mask(pref.week, pref.itemId, pref.partId)));
    final today = ref.watch(todayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: label),
            TinyBadge(dailySummary(mask)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < daysPerWeek; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: _DayChip(
                  day: dayOfWeek(classDate, i),
                  on: isDayOn(mask, i),
                  isToday: dayOfWeek(classDate, i) == today,
                  future: isFutureDay(dayOfWeek(classDate, i), today),
                  onTap: () => ref
                      .read(courseRecordProvider.notifier)
                      .setValue(pref.week, pref.itemId, pref.partId, toggleDay(mask, i)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.on,
    required this.isToday,
    required this.future,
    required this.onTap,
  });

  final DateTime day;
  final bool on;
  final bool isToday;
  final bool future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = on ? p.onPrimary : (future ? p.hint : p.ink);
    return Semantics(
      button: !future,
      selected: on,
      label: '${mdw(day)}${on ? ' 했어요' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: future ? null : onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: on ? p.primary : (future ? p.surfaceMuted : p.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToday ? (on ? p.onPrimarySoft : p.primary) : (on ? p.primary : p.line),
              width: isToday ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekdayLabel(day.weekday),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                ),
                Text(
                  md(day),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

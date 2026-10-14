import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../../../core/models/course.dart';

/// 한 주 일정의 글 칸들 (교재·훈련 내용·암송구절·나눔). 빈 칸은 숨겨요.
/// 이번 주 일정 카드와 일정표가 같이 씁니다.
class WeekDetails extends StatelessWidget {
  const WeekDetails({super.key, required this.week, this.dense = false});

  final WeekInfo week;

  /// 일정표 목록처럼 좁게
  final bool dense;

  /// 글 한 줄짜리 칸 (아이콘, 이름, 글). 암송구절은 따로 그려요.
  static List<(IconData, String, String)> textRowsOf(WeekInfo w) => [
    (Icons.book_rounded, '교재', w.book),
    (Icons.menu_book_rounded, '훈련 내용', w.title),
    (Icons.forum_rounded, '나눔', w.sharing),
  ];

  static List<Verse> versesOf(WeekInfo w) => [
    for (final v in w.verses)
      if (!v.isEmpty) v,
  ];

  static bool hasAny(WeekInfo w) => textRowsOf(w).any((r) => r.$3.trim().isNotEmpty) || versesOf(w).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final r in textRowsOf(week))
        if (r.$3.trim().isNotEmpty) r,
    ];
    final verses = versesOf(week);
    final gap = SizedBox(height: dense ? 8 : 12);
    // 훈련 내용 다음에 암송구절, 그 다음 나눔 (교재·훈련 내용 / 구절 / 나눔 순서)
    final before = rows.where((r) => r.$2 != '나눔').toList();
    final after = rows.where((r) => r.$2 == '나눔').toList();
    final children = <Widget>[
      for (final r in before) _LabeledRow(icon: r.$1, label: r.$2, child: _plain(r.$3)),
      if (verses.isNotEmpty)
        _LabeledRow(
          icon: Icons.format_quote_rounded,
          label: '암송구절',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < verses.length; i++) ...[
                if (i > 0) SizedBox(height: dense ? 8 : 12),
                _VerseView(verse: verses[i], dense: dense),
              ],
            ],
          ),
        ),
      for (final r in after) _LabeledRow(icon: r.$1, label: r.$2, child: _plain(r.$3)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) gap, children[i]],
      ],
    );
  }

  Widget _plain(String text) => Text(text.trim(), style: TextStyle(fontSize: dense ? 14 : 15, height: 1.45));
}

/// 아이콘 + 작은 이름 + 내용 한 묶음
class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: p.primary),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.inkSoft, height: 1.5),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// 암송구절 하나: 본문을 크게, 장절은 아래 작게. 본문이 없으면 장절만.
class _VerseView extends StatelessWidget {
  const _VerseView({required this.verse, required this.dense});

  final Verse verse;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = verse.text.trim();
    final ref = verse.ref.trim();
    if (text.isEmpty) return Text(ref, style: TextStyle(fontSize: dense ? 14 : 15, height: 1.45));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(fontSize: dense ? 15 : 17, fontWeight: FontWeight.w600, height: 1.55),
        ),
        if (ref.isNotEmpty) ...[
          const SizedBox(height: 2),
          MutedText(ref, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

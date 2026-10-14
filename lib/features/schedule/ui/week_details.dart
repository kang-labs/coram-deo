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

  static List<(IconData, String, String)> rowsOf(WeekInfo w) => [
    (Icons.book_rounded, '교재', w.book),
    (Icons.menu_book_rounded, '훈련 내용', w.title),
    (Icons.format_quote_rounded, '암송구절', w.verses),
    (Icons.forum_rounded, '나눔', w.sharing),
  ];

  static bool hasAny(WeekInfo w) => rowsOf(w).any((r) => r.$3.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = [
      for (final r in rowsOf(week))
        if (r.$3.trim().isNotEmpty) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : (dense ? 6 : 10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(rows[i].$1, size: 18, color: p.primary),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    rows[i].$2,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.inkSoft, height: 1.5),
                  ),
                ),
                Expanded(
                  child: Text(rows[i].$3.trim(), style: TextStyle(fontSize: dense ? 14 : 15, height: 1.45)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

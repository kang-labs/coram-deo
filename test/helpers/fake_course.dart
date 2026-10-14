import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/core/models/course_defaults.dart';

/// 테스트용 반: 제자대학2학기 (토요일, 1주 = 2026-09-12)
Course fakeCourse() {
  final weeks = fillWeeks(DateTime.utc(2026, 9, 12), 12, const []);
  return Course(
    id: 'jedae2',
    name: '제자대학2학기',
    term: '22기 2학기',
    weekday: DateTime.saturday,
    time: '18:00',
    order: 7,
    weeks: [
      for (var i = 0; i < weeks.length; i++)
        weeks[i].copyWith(
          book: i < 6 ? '세계비전의 기쁨 I' : '세계비전의 기쁨 II',
          title: i == 2 ? '추석 연휴 (휴강)' : '${i + 1}주 훈련',
          verses: i == 5 ? '요 4:35\n행 2:47' : '',
          off: i == 2,
        ),
    ],
    extras: const [ExtraRow(label: '개강', date: '2026-09-06', title: 'OT')],
    items: defaultItems,
    guide: defaultGuide,
  );
}

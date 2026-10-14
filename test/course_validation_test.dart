import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/core/models/course_limits.dart';
import 'package:coram_deo/features/admin/logic/course_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_course.dart';

void main() {
  final ok = fakeCourse();

  test('정상 반은 통과', () => expect(validateCourse(ok), isNull));

  test('규칙과 같은 길이·개수 제한', () {
    expect(validateCourse(ok.copyWith(name: '  ')), contains('반 이름'));
    expect(validateCourse(ok.copyWith(name: 'a' * (CourseLimits.name + 1))), contains('${CourseLimits.name}자'));
    expect(validateCourse(ok.copyWith(term: 'a' * (CourseLimits.term + 1))), contains('기수'));
    expect(validateCourse(ok.copyWith(time: 'a' * (CourseLimits.time + 1))), contains('수업 시간'));
    expect(validateCourse(ok.copyWith(guide: 'a' * (CourseLimits.guide + 1))), contains('기록요령'));
    expect(
      validateCourse(
        ok.copyWith(
          extras: List.filled(CourseLimits.extras + 1, const ExtraRow(label: '', date: '')),
        ),
      ),
      contains('추가 줄'),
    );
    expect(validateCourse(ok.copyWith(items: const [])), contains('하나 이상'));
    final many = [
      for (var i = 0; i <= CourseLimits.items; i++)
        ItemDef(
          id: 'i$i',
          label: 'x',
          parts: const [PartDef(id: 'main', label: 'x', type: PartType.mark)],
        ),
    ];
    expect(validateCourse(ok.copyWith(items: many)), contains('${CourseLimits.items}개'));
  });

  test('주 날짜: 비면 안 되고, 앞 주보다 7일 이상 뒤', () {
    final weeks = [...ok.weeks];
    expect(validateCourse(ok.copyWith(weeks: [...weeks]..[3] = weeks[3].copyWith(date: ''))), '4주 날짜를 정해 주세요.');
    expect(
      validateCourse(ok.copyWith(weeks: [...weeks]..[3] = weeks[3].copyWith(date: '2026-09-28'))),
      contains('4주 날짜'),
    );
    expect(
      validateCourse(ok.copyWith(weeks: [...weeks]..[1] = weeks[1].copyWith(date: '2026-09-12'))),
      contains('2주 날짜'),
    );
    // 2주 뒤로 미뤄진 주(14일 차이)는 괜찮아요
    final shifted = [
      for (final w in weeks)
        w.copyWith(date: w.classDate!.add(const Duration(days: 7)).toIso8601String().substring(0, 10)),
    ];
    expect(validateCourse(ok.copyWith(weeks: [weeks[0], ...shifted.skip(1)])), isNull);
  });

  test('항목·칸 id 겹침', () {
    expect(validateCourse(ok.copyWith(items: [ok.items[0], ok.items[0]])), contains('id가 겹쳐요'));
    const dup = ItemDef(
      id: 'x',
      label: '중복',
      parts: [
        PartDef(id: 'a', label: '1', type: PartType.mark),
        PartDef(id: 'a', label: '2', type: PartType.mark),
      ],
    );
    expect(validateCourse(ok.copyWith(items: [dup])), contains('칸 id가 겹쳐요'));
  });
}

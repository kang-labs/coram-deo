import 'package:coram_deo/core/models/course_defaults.dart';
import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('칸 값 넣고 읽기, 빈 값은 지워짐', () {
    var r = CourseRecord.empty.withValue(6, 'attend', 'review', 'o');
    expect(r.value(6, 'attend', 'att'), isNull);
    expect(r.value(6, 'attend', 'review'), 'o');
    r = r.withValue(6, 'bible', 'main', 127);
    expect(r.mask(6, 'bible', 'main'), 127);
    expect(r.mask(5, 'bible', 'main'), 0);
    r = r.withValue(6, 'attend', 'review', null).withValue(6, 'bible', 'main', 0);
    expect(r.isEmpty, isTrue);
  });

  test('JSON: 주차 → 항목 id → 칸 id → 값', () {
    final r = CourseRecord.empty
        .withValue(6, 'attend', 'att', 'o')
        .withValue(6, 'attend', 'review', 'dot')
        .withValue(6, 'bible', 'main', 127);
    expect(r.toJson(), '{"6":{"attend":{"att":"o","review":"dot"},"bible":{"main":127}}}');
    expect(CourseRecord.fromJson(r.toJson()), r);
  });

  test('예전(v1) 칸 순번 목록도 읽어서 기본 칸 id로 옮김', () {
    final r = CourseRecord.fromJson('{"6":{"attend":["o","late"],"friday":[null,"x","o"],"bible":[5],"item_k":["o"]}}');
    expect(r.value(6, 'attend', 'att'), 'o');
    expect(r.value(6, 'attend', 'review'), 'late');
    expect(r.value(6, 'friday', 'att'), isNull);
    expect(r.value(6, 'friday', 'review'), 'x');
    expect(r.value(6, 'friday', 'pulpit'), 'o');
    expect(r.mask(6, 'bible', 'main'), 5);
    expect(r.value(6, 'item_k', 'p0'), 'o'); // 기본 항목이 아니면 p0, p1 …
    expect(r.toJson(), contains('"attend":{"att":"o","review":"late"}'));
  });

  test('기본 칸 id가 순번과 맞음', () {
    expect(legacyPartId('friday', 2), 'pulpit');
    expect(legacyPartId('prep', 0), 'main');
    expect(legacyPartId('prep', 3), 'p3');
  });

  test('깨진 JSON이나 이상한 값은 건너뜀', () {
    expect(CourseRecord.fromJson('not json').isEmpty, isTrue);
    expect(CourseRecord.fromJson('[1,2]').isEmpty, isTrue);
    final r = CourseRecord.fromJson('{"x":{"a":{"main":"o"}},"3":{"a":{"main":true,"p":"late"},"b":"bad"}}');
    expect(r.value(3, 'a', 'main'), isNull);
    expect(r.value(3, 'a', 'p'), 'late');
    expect(r.value(3, 'b', 'main'), isNull);
  });
}

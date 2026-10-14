import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('칸 값 넣고 읽기, 빈 값은 지워짐', () {
    var r = CourseRecord.empty.withValue(6, 'attend', 1, 'o');
    expect(r.value(6, 'attend', 0), isNull);
    expect(r.value(6, 'attend', 1), 'o');
    r = r.withValue(6, 'bible', 0, 127);
    expect(r.mask(6, 'bible', 0), 127);
    expect(r.mask(5, 'bible', 0), 0);
    r = r.withValue(6, 'attend', 1, null).withValue(6, 'bible', 0, 0);
    expect(r.isEmpty, isTrue);
  });

  test('JSON 모양이 설계서와 같음', () {
    final r = CourseRecord.empty
        .withValue(6, 'attend', 0, 'o')
        .withValue(6, 'attend', 1, 'o')
        .withValue(6, 'bible', 0, 127);
    expect(r.toJson(), '{"6":{"attend":["o","o"],"bible":[127]}}');
    expect(CourseRecord.fromJson(r.toJson()), r);
  });

  test('깨진 JSON이나 이상한 값은 건너뜀', () {
    expect(CourseRecord.fromJson('not json').isEmpty, isTrue);
    expect(CourseRecord.fromJson('[1,2]').isEmpty, isTrue);
    final r = CourseRecord.fromJson('{"x":{"a":["o"]},"3":{"a":[true,"late"],"b":"bad"}}');
    expect(r.value(3, 'a', 0), isNull);
    expect(r.value(3, 'a', 1), 'late');
    expect(r.value(3, 'b', 0), isNull);
  });
}

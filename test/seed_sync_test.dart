import 'dart:convert';
import 'dart:io';

import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/core/models/course_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

/// tool/dev/seed.py의 기본 항목·기록요령이 앱(course_defaults.dart)과 같은지. 파이썬이 없으면 건너뜀.
void main() {
  test('seed.py 기본값 = 앱 기본값, 제자대학2학기 일정이 앱 모델로 읽힘', () async {
    final ProcessResult r;
    try {
      r = await Process.run('python', ['tool/dev/seed.py', '--dry-run'], stdoutEncoding: utf8);
    } on ProcessException {
      markTestSkipped('python 없음');
      return;
    }
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final all = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    expect(all.length, 7);
    for (final e in all.entries) {
      final c = Course.fromMap(e.key, e.value as Map<String, dynamic>);
      expect(c.items, defaultItems, reason: e.key);
      expect(c.guide, defaultGuide, reason: e.key);
    }
    final jedae2 = Course.fromMap('jedae2', all['jedae2'] as Map<String, dynamic>);
    expect(jedae2.weeks.length, 12);
    expect(jedae2.classDates.every((d) => d != null && d.weekday == DateTime.saturday), isTrue);
    expect(jedae2.weeks[2].off, isTrue);
    expect(jedae2.weeks.where((w) => w.off).length, 1);
    expect(jedae2.weeks[0].verses.first.text, startsWith('하나님의 약속은'));
    expect(jedae2.weeks.skip(1).expand((w) => w.verses).every((v) => v.text.isEmpty), isTrue);
    expect(jedae2.weeks[3].verses, const [Verse(ref: '딤후 2:21'), Verse(ref: '딤전 4:7,8')]);
    // 나눔은 한 줄 (줄바꿈 없음)
    expect(jedae2.weeks.every((w) => !w.sharing.contains('\n')), isTrue);
    expect(jedae2.weeks[1].sharing, '제자삼는 세계비전 part1 1,2장');
    expect(jedae2.weeks[5].sharing, 'part2 1,2장');
    expect(jedae2.weeks[6].book, '세계비전의 기쁨 II');
    expect(jedae2.extras.map((x) => x.label), ['개강', '졸업예배']);
  });
}

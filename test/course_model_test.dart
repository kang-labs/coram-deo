import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/core/models/course_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_course.dart';

void main() {
  test('Course toMap → fromMap 그대로', () {
    final c = fakeCourse();
    expect(Course.fromMap(c.id, c.toMap()), c);
    expect(c.toMap()['weeks'][0]['book'], '세계비전의 기쁨 I');
    expect(c.toMap()['items'][0], {
      'id': 'attend',
      'label': '출석/후기',
      'parts': [
        {'id': 'att', 'label': '출석', 'type': 'attend'},
        {'id': 'review', 'label': '후기', 'type': 'mark'},
      ],
    });
  });

  test('빠진 값은 기본값, updatedAt Timestamp 읽기', () {
    final c = Course.fromMap('x', {'name': '반', 'updatedAt': Timestamp.fromMillisecondsSinceEpoch(0)});
    expect(c.weekday, DateTime.saturday);
    expect(c.visible, isTrue);
    expect(c.weeks, isEmpty);
    expect(c.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(PartType.fromName('unknown'), PartType.mark);
  });

  test('값 비교 ==: 같은 내용이면 같고, 하나라도 다르면 다름', () {
    expect(fakeCourse(), fakeCourse());
    expect(fakeCourse().hashCode, fakeCourse().hashCode);
    final c = fakeCourse();
    expect(c.copyWith(weeks: [...c.weeks]..[0] = c.weeks[0].copyWith(book: '다른 교재')), isNot(c));
  });

  test('기본 항목 15개, id는 겹치지 않는 영문', () {
    expect(defaultItems.length, 15);
    final ids = defaultItems.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every(RegExp(r'^[a-z]+$').hasMatch), isTrue);
    expect(defaultItems.firstWhere((e) => e.id == 'friday').parts.length, 3);
  });

  test('칸 id 없는 예전 서버 문서는 기본 칸 id로 읽음, 항목·칸 id는 겹치지 않음', () {
    final item = ItemDef.fromMap({
      'id': 'friday',
      'label': '금요기도회',
      'parts': [
        {'label': '출석', 'type': 'mark'},
        {'label': '후기', 'type': 'mark'},
        {'label': '강단기도', 'type': 'mark'},
      ],
    });
    expect(item.parts.map((p) => p.id), ['att', 'review', 'pulpit']);
    expect(
      Course.fromMap('x', {
        'items': [
          ItemDef.fromMap({
            'id': 'item_a',
            'parts': [
              {'type': 'ox'},
            ],
          }).toMap(),
        ],
      }).items.single.parts.single.id,
      'p0',
    );
    for (final i in defaultItems) {
      final ids = i.parts.map((p) => p.id).toSet();
      expect(ids.length, i.parts.length, reason: i.id);
    }
    expect(defaultItems.firstWhere((e) => e.id == 'verse').parts.single.type, PartType.ox);
    expect(PartType.mark.choices, [MarkValue.o, MarkValue.x, MarkValue.dot]);
    expect(PartType.attend.choices.map((v) => v.buttonLabel), ['○', 'X', '지각']);
  });

  test('새 항목 id는 기존과 겹치지 않음', () {
    final now = DateTime.utc(2026, 10, 14);
    final a = newItemId(['attend'], now: now);
    expect(newItemId([a], now: now), isNot(a));
    final p = newPartId(const [], now: now);
    expect(newPartId([p], now: now), isNot(p));
  });

  test('1주 날짜로 7일씩 채우기, 내용은 순서대로 유지', () {
    final weeks = fillWeeks(DateTime.utc(2026, 9, 12), 3, const [WeekInfo(date: '', title: '1과')]);
    expect(weeks.map((w) => w.date), ['2026-09-12', '2026-09-19', '2026-09-26']);
    expect(weeks[0].title, '1과');
  });
}

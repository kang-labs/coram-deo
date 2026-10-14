import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/core/models/course_defaults.dart';
import 'package:coram_deo/features/course/data/course_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_course.dart';

void main() {
  test('Course toMap → fromMap 그대로', () {
    final c = fakeCourse();
    expect(Course.fromMap(c.id, c.toMap()), c);
    expect(c.toMap()['weeks'][0]['book'], '세계비전의 기쁨 I');
    expect(c.toMap()['items'][0], {
      'id': 'attend',
      'label': '훈련',
      'parts': [
        {'id': 'att', 'label': '출석', 'type': 'attend'},
        {'id': 'review', 'label': '후기', 'type': 'mark'},
      ],
    });
  });

  test('암송구절: 목록 읽기, 예전 여러 줄 글은 장절만', () {
    expect(Verse.listFrom('고후 1:20\n엡 6:10,11\n'), const [Verse(ref: '고후 1:20'), Verse(ref: '엡 6:10,11')]);
    expect(
      Verse.listFrom([
        {'ref': '요 4:35', 'text': '본문'},
      ]),
      const [Verse(ref: '요 4:35', text: '본문')],
    );
    expect(Verse.listFrom(null), isEmpty);
    final w = WeekInfo.fromMap({'date': '2026-09-12', 'verses': '요 4:35'});
    expect(WeekInfo.fromMap(w.toMap()), w);
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

  test('dotReason: 기본 true는 저장에서 빼고, 없으면 true로 읽음, 강사 특별과제만 false', () {
    const p = PartDef(id: 'main', label: '과제', type: PartType.mark);
    expect(p.toMap().containsKey('dotReason'), isFalse);
    final off = p.copyWith(dotReason: false);
    expect(off.toMap()['dotReason'], false);
    expect(PartDef.fromMap(off.toMap(), itemId: 'task', index: 0), off);
    expect(PartDef.fromMap(p.toMap(), itemId: 'task', index: 0).dotReason, isTrue);
    expect(off.needsNote(MarkValue.dot), isFalse);
    expect(p.needsNote(MarkValue.dot), isTrue);
    expect(p.needsNote(MarkValue.o), isFalse);
    expect(
      [
        for (final i in defaultItems)
          for (final q in i.parts)
            if (!q.dotReason) i.id,
      ],
      ['task'],
    );
  });

  test('서버 형식이 이상하거나 모르는 값이어도 멈추지 않고 기본값으로 읽음', () {
    final c = Course.fromMap('x', {
      'name': 3,
      'term': ['a'],
      'weekday': '토',
      'order': 2.7,
      'visible': 'yes',
      'guide': null,
      'newField': {'future': true},
      'weeks': [
        'not a map',
        42,
        {
          'date': 20261012,
          'title': ['x'],
          'verses': [
            1,
            'a',
            {'ref': 5, 'text': '본문'},
            {'ref': '요 1:1'},
          ],
          'off': 1,
        },
        {
          'date': '2026-10-17',
          'verses': {'weird': 'shape'},
          'extra': 1,
        },
      ],
      'extras': 'nope',
      'items': [
        {'id': 'a', 'label': '가', 'parts': 'nope'},
        {
          'id': 'b',
          'label': '나',
          'parts': [
            null,
            {'type': 'futureType', 'label': 1, 'dotReason': 'no'},
          ],
        },
        7,
      ],
      'updatedAt': 'yesterday',
    });
    expect(c.name, '');
    expect(c.term, '');
    expect(c.weekday, DateTime.saturday);
    expect(c.order, 2);
    expect(c.visible, isTrue);
    expect(c.weeks.length, 2);
    expect(c.weeks[0].date, '');
    expect(c.weeks[0].off, isFalse);
    expect(c.weeks[0].verses, const [Verse(ref: '', text: '본문'), Verse(ref: '요 1:1')]);
    expect(c.weeks[1].verses, isEmpty);
    expect(c.extras, isEmpty);
    expect(c.items.map((i) => i.parts.length), [0, 1]);
    final part = c.items[1].parts.single;
    expect((part.type, part.label, part.dotReason, part.id), (PartType.mark, '', true, 'p0'));
    expect(c.updatedAt, isNull);
  });

  test('저장소: 읽을 수 없는 문서는 null(목록에서 건너뜀)', () {
    expect(CourseRepository.parseCourse('ok', {'name': '반'})?.name, '반');
    // 지금 형식으로는 어떤 값도 예외가 안 나지만, 혹시 나도 null
    expect(
      CourseRepository.parseCourse('x', {
        'weeks': [
          {'date': Object()},
        ],
      }),
      isNotNull,
    );
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

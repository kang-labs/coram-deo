import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';

import '../dates.dart';
import 'course_defaults.dart' show legacyPartId;

// ── 서버 값 읽기 도우미 ──
// 서버 데이터 형식이 바뀌어도 이미 설치된 앱이 깨지지 않게, 읽기는 관대하게:
// 타입이 다르거나 없으면 기본값, 모양이 다른 목록 항목은 건너뛰어요. (캐스트로 예외를 내지 않아요)

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;

String? _strOrNull(Object? v) => v is String ? v : null;

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

int _int(Object? v, int fallback) => v is num && v.isFinite ? v.toInt() : fallback;

/// 맵들의 목록만 골라요 (목록이 아니면 빈 목록, 맵이 아닌 항목은 건너뜀)
List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) {for (final en in e.entries) '${en.key}': en.value},
];

/// 체크 칸 하나의 입력 종류. 저장 키는 [name]이라 이름을 바꾸지 마세요.
enum PartType {
  /// ○ / X / · (교재예습, 후기, 참석 등)
  mark('○ / X / ·', [MarkValue.o, MarkValue.x, MarkValue.dot]),

  /// ○ / X (구절암송)
  ox('○ / X', [MarkValue.o, MarkValue.x]),

  /// ○ / X / 지각 (출석)
  attend('○ / X / 지각', [MarkValue.o, MarkValue.x, MarkValue.late]),

  /// 7일 체크 → 한 날 수
  days('요일 (날 수)', []),

  /// 7일 체크 → 새벽기도 점수
  dawn('요일 (새벽 점수)', []);

  const PartType(this.label, this.choices);

  /// 관리자 편집 화면에 보이는 이름
  final String label;

  /// 고르는 칸의 선택지(버튼 순서). 비어 있으면 요일 칸.
  final List<MarkValue> choices;

  /// 요일 7칸으로 체크하는 종류
  bool get isDaily => choices.isEmpty;

  static PartType fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return mark;
  }
}

/// 고르는 칸의 값. [code]가 폰에 저장되는 값입니다(바꾸지 마세요).
enum MarkValue {
  o('o', '○', '○'),
  x('x', 'X', 'X'),
  dot('dot', '·', '·'),
  late('late', '지', '지각');

  const MarkValue(this.code, this.symbol, this.buttonLabel);

  final String code;

  /// 표에 보이는 글자 (읽어 주기·복사용. 화면은 MarkGlyph로 그려요)
  final String symbol;

  /// 버튼 이름 (지각처럼 표보다 길게)
  final String buttonLabel;

  /// 고를 때 사유를 적는 값 (· = 이번 주 해당 없음 등). 칸마다 끌 수 있어요(PartDef.dotReason).
  bool get needsNote => this == dot;

  static MarkValue? fromCode(Object? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 항목 안의 칸 하나 (예: 훈련 항목의 '출석').
/// [id]는 항목 안에서 겹치지 않는 키로, 폰 기록과 이어지니 바꾸지 않습니다.
@immutable
class PartDef {
  const PartDef({required this.id, required this.label, required this.type, this.dotReason = true});

  final String id;
  final String label;
  final PartType type;

  /// · 를 고를 때 사유를 받는지 (강사 특별과제처럼 ·가 '과제 없음'뿐이면 false).
  /// 저장할 때 true(기본값)면 빼고, 없으면 true로 읽어요.
  final bool dotReason;

  /// 이 칸에서 [v]를 고를 때 사유를 받아야 하는지
  bool needsNote(MarkValue v) => v.needsNote && dotReason;

  /// [itemId]·[index]는 id가 없던 예전 문서를 읽을 때 기본 칸 id를 정하는 데 씁니다.
  factory PartDef.fromMap(Map<String, dynamic> m, {required String itemId, required int index}) {
    final id = m['id'];
    return PartDef(
      id: id is String && id.isNotEmpty ? id : legacyPartId(itemId, index),
      label: _str(m['label']),
      type: PartType.fromName(_strOrNull(m['type'])),
      dotReason: m['dotReason'] != false,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'type': type.name, if (!dotReason) 'dotReason': false};

  PartDef copyWith({String? label, PartType? type, bool? dotReason}) =>
      PartDef(id: id, label: label ?? this.label, type: type ?? this.type, dotReason: dotReason ?? this.dotReason);

  @override
  bool operator ==(Object other) =>
      other is PartDef && other.id == id && other.label == label && other.type == type && other.dotReason == dotReason;

  @override
  int get hashCode => Object.hash(id, label, type, dotReason);
}

/// 체크 항목 하나. [id]는 폰 기록과 이어지는 키라 바꾸지 않습니다.
@immutable
class ItemDef {
  const ItemDef({required this.id, required this.label, required this.parts});

  final String id;
  final String label;
  final List<PartDef> parts;

  factory ItemDef.fromMap(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final raw = _maps(m['parts']);
    return ItemDef(
      id: id,
      label: _str(m['label']),
      parts: [for (var i = 0; i < raw.length; i++) PartDef.fromMap(raw[i], itemId: id, index: i)],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'parts': [for (final p in parts) p.toMap()],
  };

  ItemDef copyWith({String? label, List<PartDef>? parts}) =>
      ItemDef(id: id, label: label ?? this.label, parts: parts ?? this.parts);

  @override
  bool operator ==(Object other) =>
      other is ItemDef && other.id == id && other.label == label && listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hash(id, label, Object.hashAll(parts));
}

/// 암송구절 하나: 본문(관리자가 직접 적음, 앱에 성경 본문을 넣지 않아요) + 장절
@immutable
class Verse {
  const Verse({required this.ref, this.text = ''});

  /// 장절 (예: 요 4:35)
  final String ref;

  /// 본문 (비면 장절만 보여요)
  final String text;

  factory Verse.fromMap(Map<String, dynamic> m) => Verse(ref: _str(m['ref']), text: _str(m['text']));

  Map<String, dynamic> toMap() => {'ref': ref, 'text': text};

  Verse copyWith({String? ref, String? text}) => Verse(ref: ref ?? this.ref, text: text ?? this.text);

  bool get isEmpty => ref.trim().isEmpty && text.trim().isEmpty;

  /// 서버 값 읽기: 목록({ref, text}) 또는 예전 여러 줄 글(줄마다 장절, 본문 없음)
  static List<Verse> listFrom(Object? raw) {
    if (raw is String) {
      return [
        for (final line in raw.split('\n'))
          if (line.trim().isNotEmpty) Verse(ref: line.trim()),
      ];
    }
    if (raw is List) {
      return [for (final e in _maps(raw)) Verse.fromMap(e)];
    }
    return const [];
  }

  @override
  bool operator ==(Object other) => other is Verse && other.ref == ref && other.text == text;

  @override
  int get hashCode => Object.hash(ref, text);
}

/// 일정표의 한 주 (순서 = 주차)
@immutable
class WeekInfo {
  const WeekInfo({
    required this.date,
    this.book = '',
    this.title = '',
    this.verses = const [],
    this.sharing = '',
    this.off = false,
  });

  /// 수업 날짜 'yyyy-MM-dd'
  final String date;

  /// 교재 (빈칸 가능, 예: 세계비전의 기쁨 I)
  final String book;

  /// 훈련 내용 (여러 줄)
  final String title;

  /// 암송구절 (본문 + 장절)
  final List<Verse> verses;

  /// 나눔
  final String sharing;

  /// 휴강
  final bool off;

  /// 수업 날짜 (형식이 틀리면 null)
  DateTime? get classDate => tryParseYmd(date);

  factory WeekInfo.fromMap(Map<String, dynamic> m) => WeekInfo(
    date: _str(m['date']),
    book: _str(m['book']),
    title: _str(m['title']),
    verses: Verse.listFrom(m['verses']),
    sharing: _str(m['sharing']),
    off: _bool(m['off'], false),
  );

  Map<String, dynamic> toMap() => {
    'date': date,
    'book': book,
    'title': title,
    'verses': [for (final v in verses) v.toMap()],
    'sharing': sharing,
    'off': off,
  };

  WeekInfo copyWith({String? date, String? book, String? title, List<Verse>? verses, String? sharing, bool? off}) =>
      WeekInfo(
        date: date ?? this.date,
        book: book ?? this.book,
        title: title ?? this.title,
        verses: verses ?? this.verses,
        sharing: sharing ?? this.sharing,
        off: off ?? this.off,
      );

  @override
  bool operator ==(Object other) =>
      other is WeekInfo &&
      other.date == date &&
      other.book == book &&
      other.title == title &&
      listEquals(other.verses, verses) &&
      other.sharing == sharing &&
      other.off == off;

  @override
  int get hashCode => Object.hash(date, book, title, Object.hashAll(verses), sharing, off);
}

/// 주차 밖의 일정 줄 (개강, 졸업예배 등)
@immutable
class ExtraRow {
  const ExtraRow({required this.label, required this.date, this.title = ''});

  final String label;
  final String date;
  final String title;

  DateTime? get day => tryParseYmd(date);

  factory ExtraRow.fromMap(Map<String, dynamic> m) =>
      ExtraRow(label: _str(m['label']), date: _str(m['date']), title: _str(m['title']));

  Map<String, dynamic> toMap() => {'label': label, 'date': date, 'title': title};

  ExtraRow copyWith({String? label, String? date, String? title}) =>
      ExtraRow(label: label ?? this.label, date: date ?? this.date, title: title ?? this.title);

  @override
  bool operator ==(Object other) =>
      other is ExtraRow && other.label == label && other.date == date && other.title == title;

  @override
  int get hashCode => Object.hash(label, date, title);
}

/// 반 하나 = 한 학기 과정 하나 (Firestore `courses/{id}`)
@immutable
class Course {
  const Course({
    required this.id,
    required this.name,
    this.term = '',
    this.weekday = DateTime.saturday,
    this.time = '',
    this.order = 0,
    this.visible = true,
    this.weeks = const [],
    this.extras = const [],
    this.items = const [],
    this.guide = '',
    this.updatedAt,
  });

  final String id;
  final String name;

  /// 기수·학기 글 (예: 22기 2학기)
  final String term;

  /// 수업 요일 (DateTime.weekday: 월1 … 일7)
  final int weekday;

  /// 수업 시간 'HH:mm'
  final String time;
  final int order;
  final bool visible;
  final List<WeekInfo> weeks;
  final List<ExtraRow> extras;
  final List<ItemDef> items;

  /// 기록요령 글
  final String guide;
  final DateTime? updatedAt;

  /// 주차별 수업 날짜 (형식이 틀린 주는 null). 반 하나에 한 번만 계산해 둬요.
  List<DateTime?> get classDates => _classDatesCache[this] ??= List.unmodifiable([for (final w in weeks) w.classDate]);

  static final _classDatesCache = Expando<List<DateTime?>>('classDates');

  /// 수업 요일·시간 글 (예: 토 18:00)
  String get scheduleLabel => [weekdayLabel(weekday), if (time.isNotEmpty) time].join(' ');

  factory Course.fromMap(String id, Map<String, dynamic> m) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [for (final e in _maps(m[key])) f(e)];
    final u = m['updatedAt'];
    return Course(
      id: id,
      name: _str(m['name']),
      term: _str(m['term']),
      weekday: _int(m['weekday'], DateTime.saturday).clamp(1, 7),
      time: _str(m['time']),
      order: _int(m['order'], 0),
      visible: _bool(m['visible'], true),
      weeks: list('weeks', WeekInfo.fromMap),
      extras: list('extras', ExtraRow.fromMap),
      items: list('items', ItemDef.fromMap),
      guide: _str(m['guide']),
      updatedAt: u is Timestamp ? u.toDate() : (u is DateTime ? u : null),
    );
  }

  /// 저장할 값. updatedAt은 저장소가 서버 시각으로 넣습니다.
  Map<String, dynamic> toMap() => {
    'name': name,
    'term': term,
    'weekday': weekday,
    'time': time,
    'order': order,
    'visible': visible,
    'weeks': [for (final w in weeks) w.toMap()],
    'extras': [for (final e in extras) e.toMap()],
    'items': [for (final i in items) i.toMap()],
    'guide': guide,
  };

  Course copyWith({
    String? id,
    String? name,
    String? term,
    int? weekday,
    String? time,
    int? order,
    bool? visible,
    List<WeekInfo>? weeks,
    List<ExtraRow>? extras,
    List<ItemDef>? items,
    String? guide,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    term: term ?? this.term,
    weekday: weekday ?? this.weekday,
    time: time ?? this.time,
    order: order ?? this.order,
    visible: visible ?? this.visible,
    weeks: weeks ?? this.weeks,
    extras: extras ?? this.extras,
    items: items ?? this.items,
    guide: guide ?? this.guide,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Course &&
      other.id == id &&
      other.name == name &&
      other.term == term &&
      other.weekday == weekday &&
      other.time == time &&
      other.order == order &&
      other.visible == visible &&
      listEquals(other.weeks, weeks) &&
      listEquals(other.extras, extras) &&
      listEquals(other.items, items) &&
      other.guide == guide &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    term,
    weekday,
    time,
    order,
    visible,
    Object.hashAll(weeks),
    Object.hashAll(extras),
    Object.hashAll(items),
    guide,
    updatedAt,
  );
}

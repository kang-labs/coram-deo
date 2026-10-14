import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';

import '../dates.dart';

/// 체크 칸 하나의 입력 종류. 저장 키는 [name]이라 이름을 바꾸지 마세요.
enum PartType {
  /// ○ / X
  mark('○ / X', [MarkValue.o, MarkValue.x]),

  /// ○ / 지 / X
  attend('○ / 지 / X', [MarkValue.o, MarkValue.late, MarkValue.x]),

  /// 7일 체크 → 한 날 수
  days('요일 (날 수)', []),

  /// 7일 체크 → 새벽기도 점수
  dawn('요일 (새벽 점수)', []);

  const PartType(this.label, this.choices);

  /// 관리자 편집 화면에 보이는 이름
  final String label;

  /// 고르는 칸의 선택지. 비어 있으면 요일 칸.
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

/// 고르는 칸의 값. [code]가 폰에 저장되는 값입니다.
enum MarkValue {
  o('o', '○'),
  late('late', '지'),
  x('x', 'X');

  const MarkValue(this.code, this.symbol);

  final String code;

  /// 화면·표에 보이는 글자
  final String symbol;

  static MarkValue? fromCode(Object? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 항목 안의 칸 하나 (예: 출석/후기의 '출석')
@immutable
class PartDef {
  const PartDef({required this.label, required this.type});

  final String label;
  final PartType type;

  factory PartDef.fromMap(Map<String, dynamic> m) =>
      PartDef(label: (m['label'] as String?) ?? '', type: PartType.fromName(m['type'] as String?));

  Map<String, dynamic> toMap() => {'label': label, 'type': type.name};

  PartDef copyWith({String? label, PartType? type}) => PartDef(label: label ?? this.label, type: type ?? this.type);

  @override
  bool operator ==(Object other) => other is PartDef && other.label == label && other.type == type;

  @override
  int get hashCode => Object.hash(label, type);
}

/// 체크 항목 하나. [id]는 폰 기록과 이어지는 키라 바꾸지 않습니다.
@immutable
class ItemDef {
  const ItemDef({required this.id, required this.label, required this.parts});

  final String id;
  final String label;
  final List<PartDef> parts;

  factory ItemDef.fromMap(Map<String, dynamic> m) => ItemDef(
    id: (m['id'] as String?) ?? '',
    label: (m['label'] as String?) ?? '',
    parts: [for (final p in (m['parts'] as List?) ?? const []) PartDef.fromMap(Map<String, dynamic>.from(p as Map))],
  );

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

/// 일정표의 한 주 (순서 = 주차)
@immutable
class WeekInfo {
  const WeekInfo({
    required this.date,
    this.book = '',
    this.title = '',
    this.verses = '',
    this.sharing = '',
    this.off = false,
  });

  /// 수업 날짜 'yyyy-MM-dd'
  final String date;

  /// 교재 (빈칸 가능, 예: 세계비전의 기쁨 I)
  final String book;

  /// 훈련 내용 (여러 줄)
  final String title;

  /// 암송구절 (여러 줄)
  final String verses;

  /// 나눔
  final String sharing;

  /// 휴강
  final bool off;

  /// 수업 날짜 (형식이 틀리면 null)
  DateTime? get classDate => tryParseYmd(date);

  factory WeekInfo.fromMap(Map<String, dynamic> m) => WeekInfo(
    date: (m['date'] as String?) ?? '',
    book: (m['book'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    verses: (m['verses'] as String?) ?? '',
    sharing: (m['sharing'] as String?) ?? '',
    off: (m['off'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'date': date,
    'book': book,
    'title': title,
    'verses': verses,
    'sharing': sharing,
    'off': off,
  };

  WeekInfo copyWith({String? date, String? book, String? title, String? verses, String? sharing, bool? off}) =>
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
      other.verses == verses &&
      other.sharing == sharing &&
      other.off == off;

  @override
  int get hashCode => Object.hash(date, book, title, verses, sharing, off);
}

/// 주차 밖의 일정 줄 (개강, 졸업예배 등)
@immutable
class ExtraRow {
  const ExtraRow({required this.label, required this.date, this.title = ''});

  final String label;
  final String date;
  final String title;

  DateTime? get day => tryParseYmd(date);

  factory ExtraRow.fromMap(Map<String, dynamic> m) => ExtraRow(
    label: (m['label'] as String?) ?? '',
    date: (m['date'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
  );

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

  /// 주차별 수업 날짜 (형식이 틀린 주는 null)
  List<DateTime?> get classDates => [for (final w in weeks) w.classDate];

  /// 수업 요일·시간 글 (예: 토 18:00)
  String get scheduleLabel => [weekdayLabel(weekday), if (time.isNotEmpty) time].join(' ');

  factory Course.fromMap(String id, Map<String, dynamic> m) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [
      for (final e in (m[key] as List?) ?? const []) f(Map<String, dynamic>.from(e as Map)),
    ];
    final u = m['updatedAt'];
    return Course(
      id: id,
      name: (m['name'] as String?) ?? '',
      term: (m['term'] as String?) ?? '',
      weekday: ((m['weekday'] as num?) ?? DateTime.saturday).toInt().clamp(1, 7),
      time: (m['time'] as String?) ?? '',
      order: ((m['order'] as num?) ?? 0).toInt(),
      visible: (m['visible'] as bool?) ?? true,
      weeks: list('weeks', WeekInfo.fromMap),
      extras: list('extras', ExtraRow.fromMap),
      items: list('items', ItemDef.fromMap),
      guide: (m['guide'] as String?) ?? '',
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

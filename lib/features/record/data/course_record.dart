import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 반 하나의 내 체크 기록 (폰에만 저장). 주차(1부터) → 항목 id → 칸별 값.
///
/// 칸 값: 고르는 칸은 `"o" | "x" | "late" | null`, 요일 칸은 7비트 정수(bit0 = 그 주 첫날).
/// JSON 예: `{ "6": { "attend": ["o", "o"], "bible": [127] } }`
@immutable
class CourseRecord {
  const CourseRecord([this._weeks = const {}]);

  final Map<int, Map<String, List<Object?>>> _weeks;

  static const empty = CourseRecord();

  /// [week]주차(1부터) [itemId] 항목의 [part]번째 칸 값
  Object? value(int week, String itemId, int part) {
    final parts = _weeks[week]?[itemId];
    if (parts == null || part >= parts.length) return null;
    return parts[part];
  }

  /// 요일 칸 값 (없으면 0)
  int mask(int week, String itemId, int part) {
    final v = value(week, itemId, part);
    return v is int ? v : 0;
  }

  /// 한 칸을 바꾼 새 기록. 빈 값(null·0)만 남은 항목·주차는 지웁니다.
  CourseRecord withValue(int week, String itemId, int part, Object? newValue) {
    final weeks = {for (final e in _weeks.entries) e.key: Map.of(e.value)};
    final items = weeks.putIfAbsent(week, () => {});
    final parts = List<Object?>.of(items[itemId] ?? const []);
    while (parts.length <= part) {
      parts.add(null);
    }
    parts[part] = _isEmpty(newValue) ? null : newValue;
    while (parts.isNotEmpty && parts.last == null) {
      parts.removeLast();
    }
    if (parts.isEmpty) {
      items.remove(itemId);
    } else {
      items[itemId] = List.unmodifiable(parts);
    }
    if (items.isEmpty) weeks.remove(week);
    return CourseRecord(Map.unmodifiable(weeks));
  }

  bool get isEmpty => _weeks.isEmpty;

  static bool _isEmpty(Object? v) => v == null || v == 0 || v == '';

  String toJson() => jsonEncode({
    for (final w in _weeks.entries) '${w.key}': {for (final i in w.value.entries) i.key: i.value},
  });

  /// 깨진 값은 건너뜁니다 (기록 일부가 상해도 앱이 멈추지 않게).
  factory CourseRecord.fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    try {
      final raw = jsonDecode(json);
      if (raw is! Map) return empty;
      final weeks = <int, Map<String, List<Object?>>>{};
      for (final w in raw.entries) {
        final week = int.tryParse('${w.key}');
        if (week == null || w.value is! Map) continue;
        final items = <String, List<Object?>>{};
        for (final i in (w.value as Map).entries) {
          if (i.value is! List) continue;
          final parts = [for (final v in i.value as List) (v is String || v is int) ? v : null];
          if (parts.any((v) => v != null)) items['${i.key}'] = List.unmodifiable(parts);
        }
        if (items.isNotEmpty) weeks[week] = items;
      }
      return CourseRecord(Map.unmodifiable(weeks));
    } on FormatException {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) => other is CourseRecord && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/course_defaults.dart' show legacyPartId;

/// 반 하나의 내 체크 기록 (폰에만 저장). 주차(1부터) → 항목 id → 칸 id → 값.
///
/// 칸 값: 고르는 칸은 `"o" | "x" | "late"`, 요일 칸은 7비트 정수(bit0 = 그 주 첫날). 빈 값은 저장하지 않아요.
/// JSON 예: `{ "6": { "attend": {"att": "o", "review": "o"}, "bible": {"main": 127} } }`
///
/// 예전(v1) 형식 `{"6": {"attend": ["o", "o"]}}`(칸 순번 목록)도 읽어서 기본 칸 id로 옮겨요.
@immutable
class CourseRecord {
  const CourseRecord([this._weeks = const {}]);

  final Map<int, Map<String, Map<String, Object>>> _weeks;

  static const empty = CourseRecord();

  /// [week]주차(1부터) [itemId] 항목의 [partId] 칸 값
  Object? value(int week, String itemId, String partId) => _weeks[week]?[itemId]?[partId];

  /// 요일 칸 값 (없으면 0)
  int mask(int week, String itemId, String partId) {
    final v = value(week, itemId, partId);
    return v is int ? v : 0;
  }

  /// 한 칸을 바꾼 새 기록. 빈 값(null·0·'')이면 지우고, 빈 항목·주차도 지웁니다.
  CourseRecord withValue(int week, String itemId, String partId, Object? newValue) {
    final weeks = {for (final e in _weeks.entries) e.key: Map.of(e.value)};
    final items = weeks.putIfAbsent(week, () => {});
    final parts = Map<String, Object>.of(items[itemId] ?? const {});
    if (_isEmpty(newValue)) {
      parts.remove(partId);
    } else {
      parts[partId] = newValue!;
    }
    if (parts.isEmpty) {
      items.remove(itemId);
    } else {
      items[itemId] = Map.unmodifiable(parts);
    }
    if (items.isEmpty) weeks.remove(week);
    return CourseRecord(Map.unmodifiable(weeks));
  }

  bool get isEmpty => _weeks.isEmpty;

  static bool _isEmpty(Object? v) => v == null || v == 0 || v == '';

  static bool _validValue(Object? v) => (v is String || v is int) && !_isEmpty(v);

  String toJson() => jsonEncode({
    for (final w in _weeks.entries) '${w.key}': {for (final i in w.value.entries) i.key: i.value},
  });

  /// 깨진 값은 건너뜁니다 (기록 일부가 상해도 앱이 멈추지 않게).
  factory CourseRecord.fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    try {
      final raw = jsonDecode(json);
      if (raw is! Map) return empty;
      final weeks = <int, Map<String, Map<String, Object>>>{};
      for (final w in raw.entries) {
        final week = int.tryParse('${w.key}');
        if (week == null || w.value is! Map) continue;
        final items = <String, Map<String, Object>>{};
        for (final i in (w.value as Map).entries) {
          final itemId = '${i.key}';
          final v = i.value;
          final parts = <String, Object>{
            // 예전 형식: 칸 순번 목록 → 기본 칸 id
            if (v is List)
              for (var k = 0; k < v.length; k++)
                if (_validValue(v[k])) legacyPartId(itemId, k): v[k] as Object,
            if (v is Map)
              for (final p in v.entries)
                if (_validValue(p.value)) '${p.key}': p.value as Object,
          };
          if (parts.isNotEmpty) items[itemId] = Map.unmodifiable(parts);
        }
        if (items.isNotEmpty) weeks[week] = Map.unmodifiable(items);
      }
      return CourseRecord(Map.unmodifiable(weeks));
    } on FormatException {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CourseRecord && const DeepCollectionEquality().equals(other._weeks, _weeks);

  @override
  int get hashCode => const DeepCollectionEquality().hash(_weeks);
}

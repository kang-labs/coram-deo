import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/course.dart';
import 'course_record.dart';

/// 폰에만 저장하는 값들 (고른 반, 내 이름, 반별 체크 기록, 지난 출석부용 반 사본). 로그인 없이 씁니다.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const courseIdKey = 'courseId';
  static const nameKey = 'name';
  static const _recordPrefix = 'rec.';
  static String recordKey(String courseId) => '$_recordPrefix$courseId';

  /// 반 문서 사본. 서버에서 반이 지워지거나 바뀌어도 지난 출석부를 그대로 보여 주려고 둬요.
  static String snapshotKey(String courseId) => 'snap.$courseId';

  String? get courseId => _prefs.getString(courseIdKey);

  Future<void> setCourseId(String id) => _prefs.setString(courseIdKey, id);

  Future<void> clearCourseId() => _prefs.remove(courseIdKey);

  /// 기록이 있는 반 id 전부
  List<String> recordCourseIds() => [
    for (final k in _prefs.getKeys())
      if (k.startsWith(_recordPrefix)) k.substring(_recordPrefix.length),
  ];

  Course? snapshot(String courseId) {
    final raw = _prefs.getString(snapshotKey(courseId));
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? Course.fromMap(courseId, m) : null;
    } catch (e) {
      debugPrint('반 사본 $courseId 를 읽지 못했어요: $e');
      return null;
    }
  }

  /// 내용이 같으면 다시 쓰지 않아요.
  Future<void> saveSnapshot(Course course) async {
    final raw = jsonEncode(course.toMap());
    if (_prefs.getString(snapshotKey(course.id)) == raw) return;
    await _prefs.setString(snapshotKey(course.id), raw);
  }

  String get name => _prefs.getString(nameKey) ?? '';

  Future<void> setName(String name) => _prefs.setString(nameKey, name);

  CourseRecord record(String courseId) => CourseRecord.fromJson(_prefs.getString(recordKey(courseId)));

  /// SharedPreferences는 메모리 값을 바로 바꾸고 디스크 쓰기만 뒤에서 하므로, 체크할 때마다 바로 저장해도 가벼워요.
  Future<void> saveRecord(String courseId, CourseRecord record) =>
      record.isEmpty ? _prefs.remove(recordKey(courseId)) : _prefs.setString(recordKey(courseId), record.toJson());
}

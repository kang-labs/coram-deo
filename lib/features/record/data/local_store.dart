import 'package:shared_preferences/shared_preferences.dart';

import 'course_record.dart';

/// 폰에만 저장하는 값들 (고른 반, 내 이름, 반별 체크 기록). 로그인 없이 씁니다.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const courseIdKey = 'courseId';
  static const nameKey = 'name';
  static String recordKey(String courseId) => 'rec.$courseId';

  String? get courseId => _prefs.getString(courseIdKey);

  Future<void> setCourseId(String id) => _prefs.setString(courseIdKey, id);

  String get name => _prefs.getString(nameKey) ?? '';

  Future<void> setName(String name) => _prefs.setString(nameKey, name);

  CourseRecord record(String courseId) => CourseRecord.fromJson(_prefs.getString(recordKey(courseId)));

  /// SharedPreferences는 메모리 값을 바로 바꾸고 디스크 쓰기만 뒤에서 하므로, 체크할 때마다 바로 저장해도 가벼워요.
  Future<void> saveRecord(String courseId, CourseRecord record) =>
      record.isEmpty ? _prefs.remove(recordKey(courseId)) : _prefs.setString(recordKey(courseId), record.toJson());
}

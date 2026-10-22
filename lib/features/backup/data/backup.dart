import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/models/course.dart';
import '../../record/data/course_record.dart';
import '../../record/data/local_store.dart';

/// 기록 저장·불러오기 파일 (JSON). 폰을 바꾸거나 앱을 다시 깔 때 기록을 옮기는 용도예요.
///
/// 형식: { app, format, savedAt, name, courseId, records: {반 id: 기록}, snapshots: {반 id: 반 문서} }
/// 앞으로 형식이 바뀌어도 읽기는 관대하게: 모르는 키는 무시, 깨진 반 하나는 건너뛰어요.
abstract final class Backup {
  static const appId = 'coram_deo';
  static const format = 1;

  /// 파일 이름 (예: coram-deo-backup-20261022.json). 한글 파일 이름이 깨지는 기기가 있어 영문으로.
  static String fileName(DateTime now) => 'coram-deo-backup-${now.year}${_two(now.month)}${_two(now.day)}.json';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 이 폰의 기록 전부를 파일 내용으로
  static String export(LocalStore store, DateTime now) {
    final ids = store.recordCourseIds()..sort();
    return const JsonEncoder.withIndent(' ').convert({
      'app': appId,
      'format': format,
      'savedAt': now.toIso8601String(),
      'name': store.name,
      'courseId': ?store.courseId,
      'records': {for (final id in ids) id: jsonDecode(store.record(id).toJson())},
      'snapshots': {
        for (final id in ids)
          if (store.snapshot(id) case final c?) id: c.toMap(),
      },
    });
  }

  /// 파일에서 읽은 내용 (아직 폰에 쓰지 않음). 이 앱 파일이 아니면 null.
  static BackupData? parse(String text) {
    try {
      final m = jsonDecode(text);
      if (m is! Map || m['app'] != appId) return null;
      final records = <String, CourseRecord>{};
      if (m['records'] case final Map recs) {
        for (final e in recs.entries) {
          final r = CourseRecord.fromJson(jsonEncode(e.value));
          if (!r.isEmpty) records['${e.key}'] = r;
        }
      }
      final snapshots = <String, Course>{};
      if (m['snapshots'] case final Map snaps) {
        for (final e in snaps.entries) {
          try {
            if (e.value case final Map<String, dynamic> map) snapshots['${e.key}'] = Course.fromMap('${e.key}', map);
          } catch (err) {
            debugPrint('불러오기: 반 ${e.key} 사본을 건너뛰어요: $err');
          }
        }
      }
      return BackupData(
        name: m['name'] is String ? m['name'] as String : '',
        courseId: m['courseId'] is String ? m['courseId'] as String : null,
        records: records,
        snapshots: snapshots,
      );
    } catch (e) {
      debugPrint('불러오기: 파일을 읽지 못했어요: $e');
      return null;
    }
  }

  /// 폰에 쓰기: 파일에 든 반의 기록·사본은 파일 것으로 바꾸고, 파일에 없는 반은 그대로 둬요.
  /// 이름은 파일에 있을 때만, 고른 반은 폰에 고른 반이 없을 때만 가져와요.
  static Future<void> restore(LocalStore store, BackupData data) async {
    for (final e in data.records.entries) {
      await store.saveRecord(e.key, e.value);
    }
    for (final c in data.snapshots.values) {
      await store.saveSnapshot(c);
    }
    if (data.name.trim().isNotEmpty) await store.setName(data.name.trim());
    if (store.courseId == null && data.courseId != null) await store.setCourseId(data.courseId!);
  }
}

/// 불러온 파일 내용
@immutable
class BackupData {
  const BackupData({required this.name, required this.courseId, required this.records, required this.snapshots});

  final String name;
  final String? courseId;
  final Map<String, CourseRecord> records;
  final Map<String, Course> snapshots;

  /// 확인 창에 보일 반 이름들 (사본이 있으면 '25기 양육훈련 · 양육A반', 없으면 id)
  List<String> get courseTitles => [for (final id in records.keys) snapshots[id]?.fullTitle ?? id];
}

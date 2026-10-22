import 'dart:convert';

import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/features/backup/data/backup.dart';
import 'package:coram_deo/features/backup/data/backup_files.dart';
import 'package:coram_deo/features/backup/ui/backup_sheet.dart';
import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:coram_deo/features/record/data/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_course.dart';

Future<LocalStore> _store(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalStore(await SharedPreferences.getInstance());
}

class _FakeFiles extends BackupFiles {
  String? saved;
  String? toPick;

  @override
  Future<bool> save(String fileName, String text) async {
    saved = text;
    return true;
  }

  @override
  Future<String?> pick() async => toPick;
}

Future<_FakeFiles> _openSheet(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final files = _FakeFiles();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp), backupFilesProvider.overrideWithValue(files)],
      child: MaterialApp(
        theme: AppTheme.of(AppThemeId.fallback),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => showBackupSheet(context), child: const Text('열기')),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return files;
}

void main() {
  testWidgets('저장하면 창이 닫히고 알림이 보임', (tester) async {
    final files = await _openSheet(tester, {'rec.jedae2': '{"1":{"qt":{"main":1}}}'});
    await tester.tap(find.text('파일로 저장하기'));
    await tester.pumpAndSettle();
    expect(files.saved, contains('"jedae2"'));
    expect(find.text('파일로 저장하기'), findsNothing);
    expect(find.text('기록을 파일로 저장했어요.'), findsOneWidget);
  });

  testWidgets('불러오기: 확인 → 창 닫히고 알림, 다른 파일이면 안내', (tester) async {
    final files = await _openSheet(tester, {});
    files.toPick = '{"app":"other"}';
    await tester.tap(find.text('파일에서 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('불러올 수 없는 파일이에요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    files.toPick = '{"app":"coram_deo","records":{"jedae2":{"1":{"qt":{"main":1}}}}}';
    await tester.tap(find.text('파일에서 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('반 1개 기록을 불러올까요?'), findsOneWidget);
    await tester.tap(find.text('불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('파일에서 불러오기'), findsNothing);
    expect(find.text('기록을 불러왔어요.'), findsOneWidget);
  });

  test('저장 → 읽기 → 새 폰에 불러오기: 기록·사본·이름·고른 반', () async {
    final old = await _store({'name': '홍길동', 'courseId': 'jedae2'});
    await old.saveRecord(
      'jedae2',
      CourseRecord.empty.withValue(6, 'attend', 'att', 'o', note: '').withValue(6, 'qt', 'main', 15),
    );
    await old.saveRecord('yangyuk_a', CourseRecord.empty.withValue(1, 'attend', 'att', 'dot', note: '휴일'));
    await old.saveSnapshot(fakeCourse().copyWith(program: 'jedae2', cohort: 22));
    final text = Backup.export(old, DateTime(2026, 10, 22));
    expect(Backup.fileName(DateTime(2026, 10, 2)), 'coram-deo-backup-20261002.json');

    final data = Backup.parse(text)!;
    expect(data.records.keys.toSet(), {'jedae2', 'yangyuk_a'});
    expect(data.courseTitles, contains('22기 제자대학2학기'));

    final fresh = await _store({});
    await Backup.restore(fresh, data);
    expect(fresh.record('jedae2'), old.record('jedae2'));
    expect(fresh.record('yangyuk_a').entry(1, 'attend', 'att'), (value: 'dot', note: '휴일'));
    expect(fresh.snapshot('jedae2')?.cohort, 22);
    expect((fresh.name, fresh.courseId), ('홍길동', 'jedae2'));
  });

  test('불러오기: 파일에 없는 반은 그대로, 이미 고른 반은 안 바꿈', () async {
    final phone = await _store({'courseId': 'jejahak_a'});
    await phone.saveRecord('jejahak_a', CourseRecord.empty.withValue(2, 'qt', 'main', 3));
    final data = Backup.parse(
      jsonEncode({
        'app': 'coram_deo',
        'courseId': 'jedae2',
        'records': {
          'jedae2': {
            '1': {
              'qt': {'main': 7},
            },
          },
        },
      }),
    )!;
    await Backup.restore(phone, data);
    expect(phone.courseId, 'jejahak_a');
    expect(phone.record('jejahak_a').mask(2, 'qt', 'main'), 3);
    expect(phone.record('jedae2').mask(1, 'qt', 'main'), 7);
  });

  test('다른 파일·깨진 파일은 null, 깨진 반 하나는 건너뜀', () {
    expect(Backup.parse('not json'), isNull);
    expect(Backup.parse(jsonEncode({'app': 'other'})), isNull);
    final data = Backup.parse(
      jsonEncode({
        'app': 'coram_deo',
        'records': {
          'bad': 'x',
          'ok': {
            '1': {
              'qt': {'main': 1},
            },
          },
        },
        'snapshots': {'bad': 3},
      }),
    )!;
    expect(data.records.keys, ['ok']);
    expect(data.snapshots, isEmpty);
  });
}

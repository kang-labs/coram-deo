import 'dart:typed_data';

import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/features/record/data/local_store.dart';
import 'package:coram_deo/features/table/data/table_image_saver.dart';
import 'package:coram_deo/features/table/logic/table_view_provider.dart';
import 'package:coram_deo/features/table/ui/check_table_tab.dart';
import 'package:coram_deo/features/table/ui/record_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_course.dart';

class _FakeSaver extends TableImageSaver {
  final saved = <(String, Uint8List)>[];

  @override
  Future<bool> save(String baseName, Uint8List png) async {
    saved.add((baseName, png));
    return true;
  }
}

Future<_FakeSaver> _pump(WidgetTester tester, Size size, {String name = '홍길동'}) async {
  SharedPreferences.setMockInitialValues({
    LocalStore.courseIdKey: 'jedae2',
    LocalStore.nameKey: name,
    TableViewController.storageKey: TableView.grid.name,
    'rec.jedae2': '{"1":{"qt":{"main":"o"}}}',
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saver = _FakeSaver();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), tableImageSaverProvider.overrideWithValue(saver)],
      child: MaterialApp(
        theme: AppTheme.of(AppThemeId.fallback),
        home: Scaffold(body: CheckTableTab(course: fakeCourse())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saver;
}

void main() {
  testWidgets('가로 화면: 모든 항목 머리가 화면 폭 안에 다 보이고 넘침이 없음', (tester) async {
    await _pump(tester, const Size(800, 400));
    final course = fakeCourse();
    for (final item in course.items) {
      final f = find.text(gridHeaderText(item.label));
      expect(f, findsOneWidget, reason: item.label);
      final r = tester.getRect(f);
      expect(r.left, greaterThanOrEqualTo(0), reason: item.label);
      expect(r.right, lessThanOrEqualTo(800), reason: item.label);
    }
    // 가로로 밀리는 영역이 없어요 (한눈에 보기)
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('세로 화면: 표는 가로로 밀림', (tester) async {
    await _pump(tester, const Size(400, 800));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final first = fakeCourse().items.first;
    final lastItem = fakeCourse().items.last;
    expect(tester.getRect(find.text(gridHeaderText(first.label))).right, lessThan(400));
    // 마지막 항목은 화면 오른쪽 밖에 있음
    expect(tester.getRect(find.text(gridHeaderText(lastItem.label)).first).left, greaterThan(400));
  });

  testWidgets('이미지로 저장: PNG를 저장기에 넘기고 알림', (tester) async {
    final saver = await _pump(tester, const Size(400, 800));
    await tester.tap(find.text('이미지로 저장'));
    await tester.pump();
    // 그림 뽑기는 실제 비동기라 진짜 시간을 줘요
    for (var i = 0; i < 20 && saver.saved.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(saver.saved, hasLength(1));
    final png = saver.saved.single.$2;
    expect(png.sublist(1, 4), [0x50, 0x4E, 0x47]); // PNG 머리말
    expect(saver.saved.single.$1, startsWith('coram_deo_'));
    await tester.pump();
    expect(find.text('갤러리에 저장했어요.'), findsOneWidget);
  });

  testWidgets('이름이 비어 있으면 저장하지 않고 안내 창', (tester) async {
    final saver = await _pump(tester, const Size(400, 800), name: '');
    await tester.tap(find.text('이미지로 저장'));
    await tester.pumpAndSettle();
    expect(find.text('이름을 먼저 적어 주세요'), findsOneWidget);
    expect(find.textContaining('설정 > 내 이름'), findsOneWidget);
    expect(saver.saved, isEmpty);
  });
}

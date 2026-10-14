import 'package:coram_deo/app/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:coram_deo/features/admin/logic/admin_providers.dart';
import 'package:coram_deo/features/admin/ui/admin_screen.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_course.dart';

Widget _app(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.of(AppThemeId.fallback), home: const AdminScreen()),
);

/// 로그인한 관리자 흉내 (이메일만)
class _FakeUser implements User {
  @override
  String? get email => 'sdmem7@gmail.com';

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('로그인 전: 구글 로그인 안내', (tester) async {
    await tester.pumpWidget(_app([authStateProvider.overrideWith((ref) => Stream.value(null))]));
    await tester.pumpAndSettle();
    expect(find.text('구글로 로그인'), findsOneWidget);
    expect(find.text('반 추가'), findsNothing);
  });

  testWidgets('관리자: 반 목록(숨김 표시)과 메뉴', (tester) async {
    final hidden = fakeCourse().copyWith(id: 'b', name: '숨긴 반', visible: false, order: 8);
    await tester.pumpWidget(
      _app([
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
        allCoursesProvider.overrideWith((ref) => Stream.value([fakeCourse(), hidden])),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('반 추가'), findsOneWidget);
    expect(find.text('제자대학2학기'), findsOneWidget);
    expect(find.text('숨김'), findsOneWidget);
    await tester.tap(find.byTooltip('더 보기').last);
    await tester.pumpAndSettle();
    expect(find.text('보이기'), findsOneWidget);
    expect(find.text('새 학기로 복사'), findsOneWidget);
  });
}

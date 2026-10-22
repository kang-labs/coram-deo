import 'package:coram_deo/features/update/data/play_update.dart';
import 'package:coram_deo/features/update/ui/update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUpdate extends PlayUpdate {
  _FakeUpdate(this.available);

  final bool available;
  int checks = 0;
  int updates = 0;

  @override
  Future<bool> hasUpdate() async {
    checks++;
    return available;
  }

  @override
  Future<void> update() async => updates++;
}

Future<void> _pump(WidgetTester tester, _FakeUpdate fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playUpdateProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: UpdatePrompt(child: Text('앱 화면'))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('새 버전이 있으면 한 번 묻고, 업데이트를 누르면 업데이트', (tester) async {
    final fake = _FakeUpdate(true);
    await _pump(tester, fake);
    expect(find.text('새 버전이 나왔어요'), findsOneWidget);
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();
    expect((fake.checks, fake.updates), (1, 1));
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('나중에를 누르면 닫고 업데이트하지 않음', (tester) async {
    final fake = _FakeUpdate(true);
    await _pump(tester, fake);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(fake.updates, 0);
    expect(find.text('새 버전이 나왔어요'), findsNothing);
  });

  testWidgets('새 버전이 없으면 아무것도 안 띄움', (tester) async {
    final fake = _FakeUpdate(false);
    await _pump(tester, fake);
    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.checks, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/course/logic/course_providers.dart';
import '../features/course/ui/course_picker_screen.dart';
import '../features/home/ui/home_shell.dart';
import '../features/profile/ui/name_screen.dart';
import '../features/record/logic/record_providers.dart';
import '../features/theme/logic/theme_providers.dart';
import '../features/update/ui/update_prompt.dart';
import 'layout.dart';
import 'theme.dart';

class CoramDeoApp extends ConsumerWidget {
  const CoramDeoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(themeIdProvider);
    return MaterialApp(
      title: '하나님앞에서',
      theme: AppTheme.of(themeId),
      // 날짜 고르기 창 등 기본 위젯 글자도 한국어로 (기기 언어가 영어여도)
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(themeId.palette),
        child: _WidthFrame(background: themeId.palette.background, child: child!),
      ),
      // 앱을 열 때 한 번 Play 새 버전 확인 (Play에서 받은 앱만)
      home: const UpdatePrompt(child: RootGate()),
    );
  }
}

/// 처음 실행: 이름 → 반 고르기 → 하단 탭 화면 (이름이 비면 이름부터)
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 관리자가 새 학기를 시작하면 반 고르기부터 다시 (하던 반은 지난 출석부로)
    ref.listen(selectedCourseOutdatedProvider, (_, outdated) {
      if (outdated) ref.read(selectedCourseIdProvider.notifier).clear();
    });
    final hasName = ref.watch(myNameProvider.select((n) => n.isNotEmpty));
    if (!hasName) return const NameScreen();
    final hasCourse = ref.watch(selectedCourseIdProvider.select((id) => id != null));
    return hasCourse ? const HomeShell() : const CoursePickerScreen();
  }
}

/// 넓은 화면(폴드 안쪽, 태블릿)에서는 앱을 가운데 알맞은 폭으로 보여줍니다.
class _WidthFrame extends StatelessWidget {
  const _WidthFrame({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const maxWidth = AppLayout.maxContentWidth;
    if (mq.size.width <= maxWidth) return child;
    return ColoredBox(
      color: background,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

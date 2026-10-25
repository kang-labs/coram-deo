import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/course.dart';
import '../logic/roster_providers.dart';
import 'roster_view.dart';

/// 반장·총무 출석부 탭 (보기만, 저장 없음)
class RosterTab extends ConsumerWidget {
  const RosterTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RosterView(course: course, members: ref.watch(myClassMembersProvider));
}

/// 관리자: 반 하나의 통합 출석부 (주차마다 보기·이미지로 저장)
class AdminRosterScreen extends ConsumerWidget {
  const AdminRosterScreen({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text('${course.fullTitle} 출석부')),
    body: RosterView(course: course, members: ref.watch(adminClassMembersProvider(course.id)), canSave: true),
  );
}

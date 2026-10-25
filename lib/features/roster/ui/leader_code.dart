import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../course/logic/course_providers.dart';
import '../../record/logic/record_providers.dart';
import '../logic/roster_providers.dart';

/// 반장·총무로 지정된 사람이 반 코드(숫자 4자리)를 넣어요. 맞으면 출석부 탭이 생겨요.
Future<void> askLeaderCode(BuildContext context, WidgetRef ref) async {
  final course = ref.read(currentCourseProvider).valueOrNull;
  final name = ref.read(myNameProvider);
  if (course == null) return;
  final code = await showTextInputDialog(
    context,
    title: '반장·총무 코드',
    message: '$name 님은 ${course.fullTitle} 반장·총무로 정해져 있어요.\n관리자에게 받은 숫자 4자리를 넣으면 반 사람들 출석부를 볼 수 있어요.',
    label: '코드',
    hint: '0000',
    maxLength: 4,
    digitsOnly: true,
    confirmText: '확인',
  );
  if (code == null || !context.mounted) return;
  final uid = await ref.read(memberUidProvider.future);
  if (!context.mounted) return;
  if (uid == null) {
    await showInfoDialog(context, body: '인터넷 연결을 확인하고 설정에서 다시 넣어 주세요.');
    return;
  }
  try {
    final ok = await ref.read(rosterRepositoryProvider).claimLeader(course.id, uid, name, code);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('확인됐어요. 아래에 출석부 탭이 생겼어요.')));
    } else {
      await showInfoDialog(
        context,
        title: '코드가 맞지 않아요',
        body: '관리자에게 받은 숫자 4자리를 다시 확인해 주세요. 설정 > 반장·총무 코드 넣기에서 다시 넣을 수 있어요.',
      );
    }
  } catch (e) {
    if (context.mounted) await showInfoDialog(context, title: '확인하지 못했어요', body: '인터넷 연결을 확인해 주세요.\n($e)');
  }
}

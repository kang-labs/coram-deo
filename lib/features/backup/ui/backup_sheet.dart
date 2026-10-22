import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../course/logic/course_providers.dart';
import '../../record/logic/record_providers.dart';
import '../data/backup.dart';
import '../data/backup_files.dart';

/// 설정 > 기록 저장·불러오기
void showBackupSheet(BuildContext context) {
  showAppSheet<void>(
    context,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 16),
        children: [
          const CardHeader(icon: Icons.save_alt_rounded, title: '기록 저장·불러오기', tone: Tone.primary),
          const SizedBox(height: 8),
          const MutedText(
            '체크 기록은 이 폰에만 있어요. 폰을 바꾸거나 앱을 다시 깔기 전에 파일로 저장하고, 새 폰에서 불러오면 그대로 이어서 쓸 수 있어요.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _save(sheet, ref),
            icon: const Icon(Icons.file_download_rounded),
            label: const Text('파일로 저장하기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _load(sheet, ref),
            icon: const Icon(Icons.file_upload_rounded),
            label: const Text('파일에서 불러오기'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _save(BuildContext context, WidgetRef ref) async {
  final store = ref.read(localStoreProvider);
  if (store.recordCourseIds().isEmpty) {
    await showInfoDialog(context, body: '아직 저장할 체크 기록이 없어요.');
    return;
  }
  final now = DateTime.now();
  try {
    final saved = await ref.read(backupFilesProvider).save(Backup.fileName(now), Backup.export(store, now));
    if (saved && context.mounted) _done(context, '기록을 파일로 저장했어요.');
  } catch (e) {
    if (context.mounted) await showInfoDialog(context, title: '저장하지 못했어요', body: '다른 위치를 골라 다시 해 주세요.\n($e)');
  }
}

Future<void> _load(BuildContext context, WidgetRef ref) async {
  final String? text;
  try {
    text = await ref.read(backupFilesProvider).pick();
  } catch (e) {
    if (context.mounted) await showInfoDialog(context, title: '파일을 열지 못했어요', body: '$e');
    return;
  }
  if (text == null || !context.mounted) return;
  final data = Backup.parse(text);
  if (data == null || data.records.isEmpty) {
    await showInfoDialog(
      context,
      title: '불러올 수 없는 파일이에요',
      body: data == null ? '하나님앞에서에서 저장한 기록 파일을 골라 주세요.' : '이 파일에는 체크 기록이 없어요.',
    );
    return;
  }
  final ok = await showConfirmDialog(
    context,
    title: '반 ${data.records.length}개 기록을 불러올까요?',
    body: '${data.courseTitles.join('\n')}\n\n이 폰에 같은 반 기록이 있으면 파일 것으로 바뀌어요. 다른 반 기록은 그대로 남아요.',
    ok: '불러오기',
  );
  if (!ok || !context.mounted) return;
  await Backup.restore(ref.read(localStoreProvider), data);
  // 폰 저장값을 다시 읽게 해요
  ref
    ..invalidate(selectedCourseIdProvider)
    ..invalidate(myNameProvider)
    ..invalidate(courseRecordProvider)
    ..invalidate(pastBooksProvider);
  if (context.mounted) _done(context, '기록을 불러왔어요.');
}

/// 끝나면 창을 닫고 알려요. 창이 열린 채로 알림을 띄우면 창 뒤에 가려져 안 보여요.
void _done(BuildContext sheet, String text) {
  final messenger = ScaffoldMessenger.of(sheet);
  Navigator.pop(sheet);
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

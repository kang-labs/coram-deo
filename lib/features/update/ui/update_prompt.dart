import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../data/play_update.dart';

/// 앱을 열 때 한 번 Play 새 버전을 확인하고, 있으면 업데이트할지 물어요.
/// '나중에'를 누르면 다음에 앱을 새로 열 때까지 다시 묻지 않아요.
class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final updater = ref.read(playUpdateProvider);
    if (!await updater.hasUpdate() || !mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: '새 버전이 나왔어요',
      body: '업데이트하면 새 기능과 고친 점을 쓸 수 있어요. 체크 기록은 그대로 남아요.',
      ok: '업데이트',
      cancel: '나중에',
    );
    if (ok) await updater.update();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

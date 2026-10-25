import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../install/ui/install_guide.dart';
import '../../record/logic/record_providers.dart';

/// 이름 안내 글 (처음 화면·설정 이름 고치기에서 같이 써요)
const nameGuide =
    '본명을 적어 주세요. 반장·총무가 출석부에서 이 이름으로 봐요.\n'
    '같은 반에 이름이 같은 분이 있으면 교회에서 정해 준 A·B·C까지 붙여 적어 주세요. (예: 홍길동A)';

/// 처음 실행: 이름을 먼저 적어야 반을 고를 수 있어요.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  void _save() {
    if (_valid) ref.read(myNameProvider.notifier).set(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const InstallBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 40, AppLayout.sidePadding, 24),
                children: [
                  Text('하나님앞에서', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const MutedText(nameGuide, style: TextStyle(fontSize: 15, height: 1.6)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: '이름', hintText: '예: 홍길동'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _valid ? _save : null, child: const Text('다음')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

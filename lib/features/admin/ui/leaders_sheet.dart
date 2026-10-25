import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../roster/logic/roster_providers.dart';

/// 관리자: 반마다 반장 이름·총무 이름·코드(숫자 4자리, 둘이 같이 씀) 정하기
Future<void> showLeadersSheet(BuildContext context, Course course) =>
    showAppSheet<void>(context, scrollable: true, builder: (_) => _LeadersSheet(course: course));

class _LeadersSheet extends ConsumerStatefulWidget {
  const _LeadersSheet({required this.course});

  final Course course;

  @override
  ConsumerState<_LeadersSheet> createState() => _LeadersSheetState();
}

class _LeadersSheetState extends ConsumerState<_LeadersSheet> {
  late final _chief = TextEditingController(text: widget.course.chief);
  late final _treasurer = TextEditingController(text: widget.course.treasurer);
  final _code = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  static final _random = Random.secure();

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    try {
      _code.text = await ref.read(adminRosterRepositoryProvider).readCode(widget.course.id);
    } catch (_) {
      // 인터넷이 없으면 빈 칸으로 (새로 정할 수 있어요)
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _chief.dispose();
    _treasurer.dispose();
    _code.dispose();
    super.dispose();
  }

  void _randomCode() => setState(() => _code.text = _random.nextInt(10000).toString().padLeft(4, '0'));

  Future<void> _save() async {
    final chief = _chief.text.trim(), treasurer = _treasurer.text.trim(), code = _code.text.trim();
    if (chief.isEmpty && treasurer.isEmpty) {
      await showInfoDialog(context, body: '반장이나 총무 이름을 적어 주세요.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      await showInfoDialog(context, body: '코드는 숫자 4자리로 정해 주세요. (랜덤 버튼을 눌러도 돼요)');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRosterRepositoryProvider)
          .saveLeaders(widget.course, chief: chief, treasurer: treasurer, code: code);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('저장했어요. 반장·총무에게 코드 $code 를 알려 주세요.')));
    } on FirebaseException catch (e) {
      if (mounted) await showInfoDialog(context, title: '저장하지 못했어요', body: '권한이나 인터넷 연결을 확인해 주세요.\n(${e.code})');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        AppLayout.sidePadding,
        0,
        AppLayout.sidePadding,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        CardHeader(icon: Icons.badge_rounded, title: '${widget.course.fullTitle} 반장·총무'),
        const SizedBox(height: 8),
        const MutedText(
          '이름은 그 사람이 앱에 적은 이름과 같게 적어 주세요(띄어쓰기는 상관없어요). '
          '그 사람이 반을 고를 때 코드를 넣으면 출석부를 볼 수 있어요.\n'
          '이름이나 코드를 바꾸면 지금 반장·총무도 코드를 다시 넣어야 해요.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _chief,
          maxLength: 20,
          decoration: const InputDecoration(labelText: '반장 이름', hintText: '예: 홍길동A'),
        ),
        TextField(
          controller: _treasurer,
          maxLength: 20,
          decoration: const InputDecoration(labelText: '총무 이름', hintText: '예: 김영희'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                enabled: !_loading,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(labelText: '코드 (숫자 4자리, 반장·총무 같이)', hintText: _loading ? '불러오는 중' : '0000'),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _randomCode,
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('랜덤'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: const Text('저장')),
      ],
    );
  }
}

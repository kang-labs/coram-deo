import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 예/아니오를 묻는 대화상자. 확인을 눌렀을 때만 true.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  String ok = '확인',
  String cancel = '취소',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: body == null ? null : Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(ok)),
          ],
        ),
      ) ??
      false;
}

/// 알려 주기만 하는 대화상자 (버튼 하나)
Future<void> showInfoDialog(BuildContext context, {String? title, required String body, String ok = '확인'}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: title == null ? null : Text(title),
      // 위아래 여백을 맞춰서(글 위 24 · 버튼 아래 24) 버튼만 아래로 처져 보이지 않게
      contentPadding: EdgeInsets.fromLTRB(24, title == null ? 24 : 16, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 20, 24),
      content: Text(body),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(ok),
        ),
      ],
    ),
  );
}

/// 글자 한 줄을 입력받는 대화상자. 취소하면 null.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? label,
  String? hint,
  int maxLength = 20,
  String confirmText = '저장',
  bool allowEmpty = false,
  String? message,
  String? helper,
  bool digitsOnly = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      label: label,
      hint: hint,
      maxLength: maxLength,
      confirmText: confirmText,
      allowEmpty: allowEmpty,
      message: message,
      helper: helper,
      digitsOnly: digitsOnly,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.confirmText,
    required this.allowEmpty,
    this.message,
    this.helper,
    this.digitsOnly = false,
  });

  final String title;
  final String initialValue;
  final String? label;
  final String? hint;
  final int maxLength;
  final String confirmText;
  final bool allowEmpty;

  /// 입력 칸 위 안내 글
  final String? message;

  /// 입력 칸 아래 흐린 안내 글
  final String? helper;

  /// 숫자만 (숫자 자판)
  final bool digitsOnly;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 12)],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            keyboardType: widget.digitsOnly ? TextInputType.number : null,
            inputFormatters: widget.digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              helperText: widget.helper,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty && !widget.allowEmpty ? null : _submit,
            child: Text(widget.confirmText),
          ),
        ),
      ],
    );
  }
}

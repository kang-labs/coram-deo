import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../../../core/models/course.dart';

/// 고른 값의 색 조합 (○ 초록, X 빨강, · 회색, 지 주황 — 실제 색은 테마)
Tone markTone(MarkValue v) => switch (v) {
  MarkValue.o => Tone.success,
  MarkValue.x => Tone.danger,
  MarkValue.dot => Tone.neutral,
  MarkValue.late => Tone.warm,
};

/// ○ / X / · / 지 표시. 글꼴마다 크기가 다른 기호 대신 직접 그려서 ○와 X의 크기·굵기를 맞춰요.
/// 버튼과 체크표가 같이 씁니다. [label]을 주면 '지' 대신 그 글자(예: 지각)를 써요.
class MarkGlyph extends StatelessWidget {
  const MarkGlyph({super.key, required this.value, required this.color, this.size = 18, this.label});

  final MarkValue value;
  final Color color;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (value == MarkValue.late) {
      return Text(
        label ?? value.symbol,
        style: TextStyle(fontSize: size * 0.85, height: 1.1, fontWeight: FontWeight.w800, color: color),
      );
    }
    return Semantics(
      label: value.symbol,
      child: CustomPaint(size: Size.square(size), painter: _MarkPainter(value, color)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.value, this.color);

  final MarkValue value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    switch (value) {
      case MarkValue.o:
        canvas.drawCircle(c, s * 0.34, stroke);
      case MarkValue.x:
        // 원과 눈으로 보기에 같은 크기가 되도록 조금 작게
        final d = s * 0.27;
        canvas.drawLine(c.translate(-d, -d), c.translate(d, d), stroke);
        canvas.drawLine(c.translate(d, -d), c.translate(-d, d), stroke);
      case MarkValue.dot:
        // ○·X와 같이 눈에 띄도록 넉넉한 점
        canvas.drawCircle(c, s * 0.18, Paint()..color = color);
      case MarkValue.late:
        break; // 글자로 그려요
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.value != value || old.color != color;
}

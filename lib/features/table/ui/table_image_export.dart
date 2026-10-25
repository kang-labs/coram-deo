import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/widgets.dart';
import '../data/table_image_saver.dart';

/// 그림 위쪽 제목 칸의 글 한 줄 모양
enum ExportLineStyle {
  /// 반 이름 같은 제목
  title(20, FontWeight.w800, false),

  /// 이름처럼 크게 보여야 하는 줄
  big(32, FontWeight.w900, false),

  /// 저장한 날짜 같은 작은 줄
  small(14, FontWeight.w600, true);

  const ExportLineStyle(this.size, this.weight, this.soft);

  final double size;
  final FontWeight weight;

  /// 흐린 글자색으로
  final bool soft;
}

/// 그림 위쪽 제목 칸의 한 줄
@immutable
class ExportLine {
  const ExportLine(this.text, [this.style = ExportLineStyle.title]);

  final String text;
  final ExportLineStyle style;
}

/// 그림 한 장의 모양: 제목 칸 + 표. 화면 크기와 상관없이 같은 모양이 되게 글자 크기 설정은 따르지 않아요.
class GridExportFrame extends StatelessWidget {
  const GridExportFrame({super.key, required this.lines, required this.grid});

  final List<ExportLine> lines;

  /// 줄이거나 밀지 않는 표 ([GridLayoutMode.full])
  final Widget grid;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      color: p.background,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l.text,
                style: TextStyle(
                  fontSize: l.style.size,
                  fontWeight: l.style.weight,
                  color: l.style.soft ? p.inkSoft : p.ink,
                ),
              ),
            ),
          const SizedBox(height: 8),
          grid,
        ],
      ),
    );
  }
}

/// [child]를 화면 밖에서 원래 크기 그대로 그려서 PNG로 만들어요 (스크롤된 화면을 찍는 게 아니에요).
/// [context]의 테마·기록(Provider) 설정을 그대로 가져가요.
Future<Uint8List> captureWidgetPng(BuildContext context, Widget child, {double pixelRatio = 2.5}) async {
  final key = GlobalKey();
  final container = ProviderScope.containerOf(context);
  final theme = Theme.of(context);
  final media = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
  final entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          // 화면 밖으로 치워 둬요 (그려지기는 해서 그림으로 뽑을 수 있어요)
          child: Transform.translate(
            offset: const Offset(-100000, 0),
            child: UncontrolledProviderScope(
              container: container,
              child: Theme(
                data: theme,
                child: MediaQuery(
                  data: media,
                  child: Material(
                    type: MaterialType.transparency,
                    child: RepaintBoundary(key: key, child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('표를 그리지 못했어요.');
    // 아주 넓은 표도 4096픽셀을 넘지 않게
    final ratio = math.min(pixelRatio, 4096 / math.max(1, boundary.size.width));
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('그림을 만들지 못했어요.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
    entry.dispose();
  }
}

/// 제목 칸 + 표를 그림으로 만들어 저장하고, 결과를 알려요 (성공: 알림 줄, 실패: 안내 창).
/// [grid]는 `mode: GridLayoutMode.full`인 표. [baseName]은 확장자 없는 파일 이름.
Future<void> exportGridImage(
  BuildContext context, {
  required String baseName,
  required List<ExportLine> lines,
  required Widget grid,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saver = ProviderScope.containerOf(context).read(tableImageSaverProvider);
  try {
    final png = await captureWidgetPng(context, GridExportFrame(lines: lines, grid: grid));
    final saved = await saver.save(baseName, png);
    // 웹은 갤러리가 없어 파일로 내려받아요
    if (saved) messenger.showSnackBar(SnackBar(content: Text(kIsWeb ? '그림 파일을 내려받았어요.' : '갤러리에 저장했어요.')));
  } catch (_) {
    if (!context.mounted) return;
    await showInfoDialog(context, title: '저장하지 못했어요', body: '그림을 저장하지 못했어요. 저장 공간이나 권한을 확인하고 다시 해 주세요.');
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

/// 표 그림(PNG) 저장. 폰은 갤러리에, 웹앱은 내려받기로 저장해요.
/// 테스트에서 바꿔 끼울 수 있게 따로 둬요.
class TableImageSaver {
  const TableImageSaver();

  /// [baseName]은 확장자 없는 파일 이름. 저장했으면 true, 취소하면 false. 실패하면 예외.
  Future<bool> save(String baseName, Uint8List png) async {
    if (kIsWeb) {
      final uri = await FilePicker.saveFile(
        fileName: '$baseName.png',
        bytes: png,
        mimeType: 'image/png',
        dialogTitle: '표 그림 저장하기',
      );
      return uri != null;
    }
    // 권한이 없으면 한 번 물어봐요 (새 안드로이드는 갤러리에 쓰는 데 권한이 필요 없어요)
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) return false;
    await Gal.putImageBytes(png, name: baseName);
    return true;
  }
}

final tableImageSaverProvider = Provider<TableImageSaver>((ref) => const TableImageSaver());

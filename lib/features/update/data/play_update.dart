import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play 스토어 인앱 업데이트. Play에서 설치한 안드로이드 앱에서만 동작해요.
/// GitHub APK·웹·테스트에서는 확인이 실패하거나 해당 없음이라 조용히 '업데이트 없음'으로 봐요.
class PlayUpdate {
  const PlayUpdate();

  /// 바로 설치할 수 있는 새 버전이 Play에 있으면 true. 앱을 열 때 한 번만 불러요(배터리·네트워크 아끼기).
  Future<bool> hasUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable && info.immediateUpdateAllowed;
    } catch (e) {
      // Play에서 받지 않은 앱(GitHub APK), Play 스토어가 없는 기기, 오프라인 등
      debugPrint('업데이트 확인 건너뜀: $e');
      return false;
    }
  }

  /// Play 화면으로 바로 업데이트해요(다 받으면 앱이 새 버전으로 다시 열려요).
  Future<void> update() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('업데이트 실패: $e');
    }
  }
}

final playUpdateProvider = Provider<PlayUpdate>((ref) => const PlayUpdate());

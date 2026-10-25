import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/firebase_providers.dart';
import 'core/local_storage.dart';
import 'core/web_env.dart';
import 'firebase_options.dart';

/// 확인용 빌드에서만 PC의 Firebase 에뮬레이터에 붙어요 (`--dart-define=USE_FIREBASE_EMULATOR=true`).
/// 실제 서버 데이터를 건드리지 않고 반장·출석부 흐름을 시험하려고 둬요. 평소 빌드는 꺼져 있어요.
const _useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

void _connectEmulators() {
  // 안드로이드 에뮬레이터에서 PC는 10.0.2.2
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
  for (final app in [Firebase.app(), Firebase.app(adminAppName)]) {
    FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(host, 8080);
    FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9099);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase와 기기 저장값을 동시에 읽어서 시작 시간을 줄입니다.
  final (_, prefs) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ).wait;
  // 관리자 로그인 전용 앱 (기본 앱의 익명 로그인 = 내 기록 자리를 건드리지 않게)
  await Firebase.initializeApp(name: adminAppName, options: DefaultFirebaseOptions.currentPlatform);
  if (_useEmulator) _connectEmulators();
  // 웹: 브라우저가 기록(저장 공간)을 자동으로 지우지 않게 요청해요. 기다리지 않아요.
  requestPersistentStorage();
  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const CoramDeoApp()));
}

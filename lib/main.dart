import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/firebase_providers.dart';
import 'core/local_storage.dart';
import 'core/web_env.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase와 기기 저장값을 동시에 읽어서 시작 시간을 줄입니다.
  final (_, prefs) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ).wait;
  // 관리자 로그인 전용 앱 (기본 앱의 익명 로그인 = 내 기록 자리를 건드리지 않게)
  await Firebase.initializeApp(name: adminAppName, options: DefaultFirebaseOptions.currentPlatform);
  // 웹: 브라우저가 기록(저장 공간)을 자동으로 지우지 않게 요청해요. 기다리지 않아요.
  requestPersistentStorage();
  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const CoramDeoApp()));
}

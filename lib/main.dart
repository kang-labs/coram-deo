import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/local_storage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase와 기기 저장값을 동시에 읽어서 시작 시간을 줄입니다.
  final (_, prefs) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ).wait;
  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const CoramDeoApp()));
}

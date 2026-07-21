import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/app_clock.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env에서 API 키를 읽는다. 파일이 없어도 앱은 (Mock으로) 그대로 뜬다.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env 미포함 시 무시 — --dart-define 또는 Mock으로 동작.
  }

  // 로컬 우선 저장소 초기화 (백엔드 서버 없음)
  await LocalStore.init();
  AppClock.load(); // 저장된 데모 날짜 오프셋 복원
  runApp(const BorderApp());
}

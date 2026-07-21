import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/app_clock.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이티브만 .env에서 키를 읽는다. 웹은 키를 브라우저에 두지 않고
  // 프록시(Cloudflare)가 주입하므로 .env를 읽지 않는다(번들에 실린 키를
  // 앱이 사용하지 않게 하려는 안전장치 — 웹 빌드용 .env는 비워 둘 것).
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env 미포함 시 무시 — --dart-define 또는 Mock으로 동작.
    }
  }

  // 로컬 우선 저장소 초기화 (백엔드 서버 없음)
  await LocalStore.init();
  AppClock.load(); // 저장된 데모 날짜 오프셋 복원
  runApp(const BorderApp());
}

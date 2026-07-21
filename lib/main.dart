import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/app_clock.dart';
import 'data/local_store.dart';

Future<void> main() async {
  // 웹의 일부 플러그인(file_picker 등)은 브라우저 이벤트 리스너에서 비동기
  // 예외를 던지는데, 이 예외는 앱의 await/try-catch로는 잡히지 않고 zone까지
  // 올라와 화면이 하얗게 죽는다. 최상위 zone에서 받아 로그만 남기고 앱은
  // 계속 살아 있게 한다(네이티브도 동일하게 안전해진다).
  runZonedGuarded(() async {
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
  }, (error, stack) {
    debugPrint('[Uncaught] $error\n$stack');
  });
}

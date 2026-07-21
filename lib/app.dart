import 'package:flutter/material.dart';

import 'ui/splash_screen.dart';

/// 앱 루트. 테마는 접근성 기본값(큰 글씨·높은 대비)만 최소로 잡아 두고,
/// 세부 디자인은 이후 별도로 다듬는다.
class BorderApp extends StatelessWidget {
  const BorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BORDER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E5AAC)),
        // 인지 접근성: 기본 글씨를 크게.
        textTheme: const TextTheme().apply(fontSizeFactor: 1.15),
      ),
      home: const SplashScreen(),
    );
  }
}

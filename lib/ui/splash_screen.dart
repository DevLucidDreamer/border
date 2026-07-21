import 'package:flutter/material.dart';

import 'timetable_screen.dart';

/// 앱을 열면 가장 먼저 뜨는 타이틀(로고) 화면.
/// 약 1초 머문 뒤 다음 화면(시간표 업로드)으로 넘어간다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// 타이틀 로고 색(틸 그린).
  static const brand = Color(0xFF1C9C82);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TimetableScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'BORDER',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 46,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: SplashScreen.brand,
          ),
        ),
      ),
    );
  }
}

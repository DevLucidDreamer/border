import 'package:flutter/material.dart';

import 'timetable_screen.dart';

/// 앱을 열면 가장 먼저 뜨는 타이틀(로고) 화면.
/// 약 2초 머문 뒤 다음 화면(시간표 업로드)으로 넘어간다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// ---- 브랜드 팔레트 (docs/메인화면.png에서 추출한 실제 색) ----
  static const brand = Color(0xFF138777); // 워드마크
  static const ink = Color(0xFF5D9A92); // 항목 제목 = 아이콘 원 색
  static const disc = Color(0xFF5D9A92); // 원형 아이콘 배경
  static const muted = Color(0xFF8E8E93); // 부제
  static const line = Color(0xFFC7C7CC); // 구분선

  /// 마스코트(거북이) 이미지 경로.
  static const mascot = 'assets/turtle.png';

  /// 메인화면에서 쓰는 얼굴만 잘라낸(테두리 없는) 마스코트.
  static const mascotFace = 'assets/turtle_face.png';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 거북이 + 바닥 그림자(타원)
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 168,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCDCDC),
                    borderRadius:
                        BorderRadius.all(Radius.elliptical(84, 13)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Image.asset(SplashScreen.mascot, width: 150),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const BorderWordmark(width: 148, height: 32),
          ],
        ),
      ),
    );
  }
}

/// 메인화면 오른쪽에서 빼꼼 내미는 얼굴.
/// 기울기·크기는 docs/메인화면.png의 머리 위치(중심 (313,226), 지름 124)에 맞췄다.
class MascotFace extends StatelessWidget {
  const MascotFace({super.key, this.width = 141});

  final double width;

  /// 목업의 머리 기울기(-32.6°).
  static const _tilt = -0.569;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: _tilt,
      child: Image.asset(SplashScreen.mascotFace, width: width),
    );
  }
}

/// 브랜드 워드마크. 목업의 글자 크기(180x39)에 정확히 맞춘다.
/// 목업이 쓰는 굵은 콘덴스드 서체가 없어, 박스에 맞춰 늘리는 방식으로 재현한다.
class BorderWordmark extends StatelessWidget {
  const BorderWordmark({super.key, this.width = 180, this.height = 39});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const FittedBox(
        fit: BoxFit.fill,
        child: Text(
          'BORDER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: SplashScreen.brand,
          ),
        ),
      ),
    );
  }
}

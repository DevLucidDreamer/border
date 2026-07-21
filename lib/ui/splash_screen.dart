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

  /// 메인화면 오른쪽 가장자리에서 빼꼼 내미는 마스코트(직선 면이 화면 끝).
  static const mascotPeek = 'assets/turtle_peek.png';

  /// BORDER 워드마크 로고(둥근 콘덴스드 서체 원본).
  static const wordmark = 'assets/border_logo.png';

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
    // 초기화면.png 레이아웃을 원본 에셋으로 직접 합성 → 어떤 해상도에서도 선명.
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
            const BorderWordmark(
                width: 148, height: 32, alignment: Alignment.center),
          ],
        ),
      ),
    );
  }
}

/// 메인화면 오른쪽 가장자리에서 빼꼼 내미는 얼굴.
/// 이미지 자체가 직선 면(=화면 끝)을 가진 빼꼼 모양이라 회전 없이 붙인다.
class MascotFace extends StatelessWidget {
  const MascotFace({super.key, this.width = 105});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(SplashScreen.mascotPeek, width: width);
  }
}

/// 브랜드 워드마크. 로고 이미지(둥근 콘덴스드 서체)를 그대로 쓴다.
/// width/height 박스 안에 비율 유지로 맞춘다(왜곡 없음).
class BorderWordmark extends StatelessWidget {
  const BorderWordmark({
    super.key,
    this.width = 180,
    this.height = 39,
    this.alignment = Alignment.centerLeft,
  });

  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        SplashScreen.wordmark,
        fit: BoxFit.contain,
        alignment: alignment,
      ),
    );
  }
}

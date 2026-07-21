import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../data/local_store.dart';
import '../services/files/file_picker_service.dart';
import 'learn_screen.dart';
import 'recording_screen.dart';
import 'splash_screen.dart';
import 'timetable_screen.dart';

/// 홈 화면. 학습의 전체 여정을 큰 항목 세 개로 압축한다.
/// (학습하기 · 녹음하기 · 자료 넣기)
///
/// 대상(경계선지능 청년)을 위해 큰 탭 영역·또렷한 아이콘·최소한의 글로
/// 인지 부담을 줄인다. 종이빛 배경 위에 떠 있는 부드러운 원형 아이콘이
/// 화면의 시그니처다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---- 팔레트 ----
  static const _paper = Color(0xFFF7F6F2); // 따뜻한 종이빛 배경
  static const _ink = Color(0xFF1A1815); // 잉크(제목·아이콘)
  static const _muted = Color(0xFF8A8A8A); // 부제
  static const _line = Color(0xFFE4E2DD); // 헤어라인 구분선

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 오늘 남은 학습·복습 세션 수(신규 단원 + 마감 복습).
  int get _pendingSessions {
    final s = Services.instance;
    return s.reviewEngine.pendingCount(
        s.unitRepository.all(), s.reviewRepository.all());
  }

  /// 다른 화면에 다녀오면(녹음·학습) 남은 개수를 다시 센다.
  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  /// 자료 넣기: 음성/PDF 중 선택 → 파일 선택 → 처리 화면으로 이동.
  Future<void> _upload() async {
    final kind = await showModalBottomSheet<PickKind>(
      context: context,
      backgroundColor: _paper,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.audiotrack, size: 32, color: _ink),
              title: const Text('음성 파일', style: TextStyle(fontSize: 20)),
              onTap: () => Navigator.pop(ctx, PickKind.audio),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, size: 32, color: _ink),
              title: const Text('PDF 파일', style: TextStyle(fontSize: 20)),
              onTap: () => Navigator.pop(ctx, PickKind.pdf),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    final picked = await Services.instance.filePicker.pick(kind);
    if (picked == null || !mounted) return;

    await _go(kind == PickKind.audio
        ? RecordingScreen.audioFile(picked.path)
        : RecordingScreen.pdfFile(picked.path));
  }

  /// 시간표 수정: 시간표 화면으로 이동(새로 찍거나 편집 후 저장).
  void _editTimetable() {
    Navigator.of(context).pop(); // 서랍 닫기
    _go(const TimetableScreen());
  }

  /// 데이터 초기화: 확인 후 모든 학습 데이터·파일을 지우고 처음 화면으로.
  Future<void> _resetData() async {
    Navigator.of(context).pop(); // 서랍 닫기
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('저장된 녹음·학습·복습·시간표를 모두 지울까요?\n되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await LocalStore.clearAll();
    await Services.instance.fileStore.wipe();
    if (!mounted) return;
    // 처음 흐름(타이틀 → 시간표 → 홈)부터 다시 시작.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('메뉴',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined, color: _ink),
              title: const Text('시간표 수정', style: TextStyle(fontSize: 20)),
              onTap: _editTimetable,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('데이터 초기화',
                  style: TextStyle(fontSize: 20, color: Colors.red)),
              onTap: _resetData,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _pendingSessions;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _paper,
      endDrawer: _buildDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // 오른쪽 위 서랍(≡) 버튼.
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 30, color: _ink),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'BORDER',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _ink,
                ),
              ),
              const Spacer(flex: 2),
              _HomeItem(
                icon: Icons.menu_book_outlined,
                title: '학습하기',
                subtitle: sessions > 0
                    ? '$sessions개의 세션이 남아있어요!'
                    : '지금은 학습할 내용이 없어요',
                onTap: () => _go(const LearnScreen()),
              ),
              const _Divider(),
              _HomeItem(
                icon: Icons.mic_none,
                title: '녹음하기',
                onTap: () => _go(RecordingScreen.record()),
              ),
              const _Divider(),
              _HomeItem(
                icon: Icons.description_outlined,
                title: '자료 넣기',
                onTap: _upload,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 원형 아이콘 뱃지 + 제목(+부제)로 이루어진 큰 탭 항목.
class _HomeItem extends StatelessWidget {
  const _HomeItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            _IconDisc(icon: icon),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: _HomeScreenState._ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 17,
                        color: _HomeScreenState._muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 종이 위에 떠 있는 듯한 부드러운 흰색 원형 아이콘 디스크.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          // 아래로 퍼지는 부드러운 그림자
          BoxShadow(color: Color(0x1A000000), blurRadius: 22, offset: Offset(0, 8)),
          // 위쪽 옅은 글로우로 '떠 있는' 느낌
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 42, color: _HomeScreenState._ink),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(right: 12),
      color: _HomeScreenState._line,
    );
  }
}

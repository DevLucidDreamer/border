import 'package:flutter/material.dart';

import '../core/app_clock.dart';
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
  static const _paper = Colors.white; // 배경
  static const _ink = SplashScreen.ink; // 항목 제목(딥 틸)
  static const _disc = SplashScreen.disc; // 원형 아이콘 배경(뮤트 틸)
  static const _muted = SplashScreen.muted; // 부제
  static const _line = SplashScreen.line; // 헤어라인 구분선

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
        ? RecordingScreen.audioFile(picked)
        : RecordingScreen.pdfFile(picked));
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

  /// 데모 모드: 시연 중 날짜를 앞당겨 복습 주기·시간표 과목분류를 즉석에서
  /// 확인한다. 실제 날짜 계산을 기다리지 않고 "다음 복습"까지 점프할 수 있다.
  Future<void> _openDemoMode() async {
    Navigator.of(context).pop(); // 서랍 닫기
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final now = AppClock.now();
          void refresh() => setSheet(() {});

          // 예정된 가장 이른 복습일로 점프.
          void jumpToNextReview() {
            final pending = Services.instance.reviewRepository
                .all()
                .where((r) => r.isPending)
                .toList();
            if (pending.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('예정된 복습이 없어요.')));
              return;
            }
            final next = pending
                .map((r) => r.dueDate)
                .reduce((a, b) => a.isBefore(b) ? a : b);
            AppClock.jumpTo(next);
            refresh();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('데모 모드',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  const SizedBox(height: 12),
                  Text('지금 앱 날짜',
                      style: const TextStyle(fontSize: 14, color: _muted)),
                  const SizedBox(height: 4),
                  Text(_fmtDate(now),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  if (AppClock.isShifted)
                    Text('실제 시간보다 ${AppClock.offset.inDays}일 빠름',
                        style: const TextStyle(fontSize: 13, color: _disc)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _demoChip('+1일',
                          () { AppClock.advance(const Duration(days: 1)); refresh(); }),
                      _demoChip('+7일',
                          () { AppClock.advance(const Duration(days: 7)); refresh(); }),
                      _demoChip('다음 복습으로', jumpToNextReview),
                      _demoChip('실제 시간으로',
                          () { AppClock.reset(); refresh(); }),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {}); // 남은 학습 개수 갱신
  }

  Widget _demoChip(String label, VoidCallback onTap) => ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFFEFEDE5),
        onPressed: onTap,
      );

  static String _fmtDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}년 ${d.month}월 ${d.day}일  $hh:$mm';
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
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.science_outlined, color: _muted),
              title: const Text('데모 모드', style: TextStyle(fontSize: 20)),
              subtitle: Text(
                AppClock.isShifted
                    ? '${_fmtDate(AppClock.now())} (조작됨)'
                    : '날짜를 앞당겨 복습을 시연해요',
                style: const TextStyle(fontSize: 13),
              ),
              onTap: _openDemoMode,
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
      // 좌표는 docs/메인화면.png(가로 347)에서 그대로 잰 값이다.
      body: SafeArea(
        child: Stack(
          children: [
            // 오른쪽 가장자리에서 얼굴만 빼꼼 내미는 마스코트(직선 면이 화면 끝에 딱 붙음).
            const Positioned(top: 150, right: 0, child: MascotFace()),
            // 오른쪽 위 서랍(≡) 버튼.
            Positioned(
              top: 0,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.menu, size: 30, color: _ink),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ),
            const Positioned(left: 15, top: 123, child: BorderWordmark()),
            Positioned(
              left: 15,
              right: 0,
              top: 281,
              child: _HomeItem(
                icon: Icons.menu_book_outlined,
                title: '학습하기',
                subtitle: sessions > 0
                    ? '$sessions개의 학습이 남아있어요!'
                    : '지금은 학습할 내용이 없어요',
                onTap: () => _go(const LearnScreen()),
              ),
            ),
            const Positioned(left: 29, right: 21, top: 371, child: _Divider()),
            Positioned(
              left: 15,
              right: 0,
              top: 408,
              child: _HomeItem(
                icon: Icons.mic_none,
                title: '녹음하기',
                onTap: () => _go(RecordingScreen.record()),
              ),
            ),
            const Positioned(left: 29, right: 21, top: 489, child: _Divider()),
            Positioned(
              left: 15,
              right: 0,
              top: 524,
              child: _HomeItem(
                icon: Icons.description_outlined,
                title: '자료 넣기',
                onTap: _upload,
              ),
            ),
          ],
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
      child: Row(
        children: [
          _IconDisc(icon: icon),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    height: 1.15,
                    color: _HomeScreenState._ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: _HomeScreenState._muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 흰 아이콘이 들어간 틸 원형 디스크(목업 지름 67).
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 67,
      height: 67,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _HomeScreenState._disc,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 34, color: Colors.white),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: _HomeScreenState._line);
  }
}

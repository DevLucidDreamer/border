import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import 'home_screen.dart';
import 'timetable_confirm_screen.dart';

/// 시간표 사진을 올려 OCR로 수업(요일·시간·강의명)을 읽는 화면.
/// 스플래시 다음에 나오며, 업로드하거나 건너뛰면 홈으로 넘어간다.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _busy = false;

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _pickAndRead() async {
    if (_busy) return;
    final s = Services.instance;
    final picked = await s.filePicker.pickImage();
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final sessions = await s.timetableOcr.extract(picked.path);
      if (!mounted) return;
      setState(() => _busy = false);
      // 저장은 확인 화면에서 "맞아요"를 누를 때 한다.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TimetableConfirmScreen(sessions: sessions),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('시간표를 읽지 못했어요. 다른 사진으로 다시 시도해 주세요.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                '시간표 사진을\n올려주세요.',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1815),
                ),
              ),
              Expanded(
                child: Center(
                  child: _busy
                      ? const _Reading()
                      : _AddButton(onTap: _pickAndRead),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _goHome,
                  child: const Text('나중에 하기',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시간표 사진을 고르는 큰 회색 원형 + 버튼.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 132,
        height: 132,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEDEDED),
        ),
        child: const Icon(Icons.add_rounded, size: 68, color: Color(0xFF9A9A9A)),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator()),
        SizedBox(height: 20),
        Text('시간표를 읽고 있어요…', style: TextStyle(fontSize: 20)),
      ],
    );
  }
}

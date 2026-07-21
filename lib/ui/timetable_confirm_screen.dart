import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/class_session.dart';
import 'home_screen.dart';

/// 시간표를 OCR로 읽은 뒤 확인·수정하는 화면.
///
/// 잘못 읽혔을 수 있으니 각 수업을 눌러 고치거나, 지우거나, 새로 추가할 수
/// 있다. "네, 맞아요"를 누를 때 비로소 저장하고 홈으로 넘어간다.
class TimetableConfirmScreen extends StatefulWidget {
  const TimetableConfirmScreen({super.key, required this.sessions});

  final List<ClassSession> sessions;

  @override
  State<TimetableConfirmScreen> createState() => _TimetableConfirmScreenState();
}

class _TimetableConfirmScreenState extends State<TimetableConfirmScreen> {
  static const _ink = Color(0xFF1A1815);

  late final List<ClassSession> _sessions = List.of(widget.sessions);

  Future<void> _save() async {
    await Services.instance.timetableRepository.replaceAll(_sessions);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _edit(int index) async {
    final edited = await _showEditSheet(_sessions[index]);
    if (edited != null) setState(() => _sessions[index] = edited);
  }

  Future<void> _add() async {
    final added = await _showEditSheet(const ClassSession(courseName: ''));
    if (added != null) setState(() => _sessions.add(added));
  }

  void _delete(int index) => setState(() => _sessions.removeAt(index));

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
                '이렇게 읽었어요.\n확인하고 고쳐 주세요.',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _sessions.isEmpty
                    ? const Center(
                        child: Text('아래 "수업 추가"로 직접 넣어 주세요.',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                      )
                    : ListView.separated(
                        itemCount: _sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _SessionCard(
                          session: _sessions[i],
                          onEdit: () => _edit(i),
                          onDelete: () => _delete(i),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, color: _ink),
                  label: const Text('수업 추가',
                      style: TextStyle(fontSize: 18, color: _ink)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sessions.isEmpty ? null : _save,
                  child: const Text('네, 맞아요', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('사진 다시 올리기',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 수업 하나를 입력/수정하는 바텀시트. 저장하면 새 [ClassSession]을 돌려준다.
  Future<ClassSession?> _showEditSheet(ClassSession initial) {
    final name = TextEditingController(text: initial.courseName);
    final day = TextEditingController(text: initial.day);
    final start = TextEditingController(text: initial.startTime);
    final end = TextEditingController(text: initial.endTime);

    Widget field(String label, TextEditingController c, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: c,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return showModalBottomSheet<ClassSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        // 키보드가 올라와도 필드가 가려지지 않도록.
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('강의명', name, '예: 경제학원론'),
            field('요일', day, '예: 월'),
            Row(
              children: [
                Expanded(child: field('시작 시간', start, '예: 09:00')),
                const SizedBox(width: 12),
                Expanded(child: field('끝나는 시간', end, '예: 10:30')),
              ],
            ),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  ClassSession(
                    courseName: name.text.trim(),
                    day: day.text.trim(),
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                  ),
                ),
                child: const Text('저장', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      day.dispose();
      start.dispose();
      end.dispose();
    });
  }
}

/// 읽어 낸 수업 하나: 강의명 + 요일·시간, 수정/삭제 버튼.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassSession session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _when {
    final parts = <String>[];
    if (session.day.isNotEmpty) parts.add(session.day);
    if (session.startTime.isNotEmpty) {
      parts.add(session.endTime.isNotEmpty
          ? '${session.startTime}~${session.endTime}'
          : session.startTime);
    }
    return parts.isEmpty ? '시간 정보 없음' : parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F6F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.courseName.isEmpty
                        ? '(강의명 없음)'
                        : session.courseName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(_when,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF8A8A8A))),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF8A8A8A)),
              tooltip: '고치기',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close, color: Color(0xFF8A8A8A)),
              tooltip: '지우기',
            ),
          ],
        ),
      ),
    );
  }
}

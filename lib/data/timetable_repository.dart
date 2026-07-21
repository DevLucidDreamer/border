import '../models/class_session.dart';
import 'local_store.dart';

/// 업로드한 시간표(수업 목록)의 로컬 영속화를 담당한다.
class TimetableRepository {
  TimetableRepository();

  final _box = LocalStore.box(LocalStore.timetableBox);

  /// 새 시간표로 통째로 교체한다(재업로드 시 이전 것은 지운다).
  Future<void> replaceAll(List<ClassSession> sessions) async {
    await _box.clear();
    await _box.putAll({
      for (var i = 0; i < sessions.length; i++) '$i': sessions[i].toMap(),
    });
  }

  List<ClassSession> all() => _box.values.map(ClassSession.fromMap).toList();

  bool get isEmpty => _box.isEmpty;

  /// 등록된 과목명 목록(빈 이름 제외).
  List<String> subjectNames() =>
      all().map((c) => c.courseName).where((n) => n.isNotEmpty).toList();

  /// 주어진 시각에 진행 중인 수업의 과목명(없으면 '').
  /// 녹음 시각을 시간표에 맞춰 과목으로 분류하는 데 쓴다.
  String subjectForTime(DateTime t) => subjectAt(all(), t);
}

/// 시간표([sessions])에서 시각 [t]에 진행 중인 수업의 과목명(없으면 '').
/// 순수 함수라 저장소 없이도 검증할 수 있다.
String subjectAt(List<ClassSession> sessions, DateTime t) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final dow = days[t.weekday - 1];
  final minutes = t.hour * 60 + t.minute;
  for (final s in sessions) {
    if (!s.day.contains(dow)) continue;
    final start = _toMinutes(s.startTime);
    if (start == null) continue;
    final end = _toMinutes(s.endTime) ?? start + 90; // 종료 없으면 90분 가정
    if (minutes >= start && minutes <= end) return s.courseName;
  }
  return '';
}

int? _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return null;
  return h * 60 + m;
}

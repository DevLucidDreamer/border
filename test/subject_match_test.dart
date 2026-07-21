import 'package:flutter_test/flutter_test.dart';

import 'package:border/data/timetable_repository.dart';
import 'package:border/models/class_session.dart';

/// 녹음 시각 → 시간표 과목 매칭(subjectAt) 검증.
void main() {
  const table = [
    ClassSession(
        courseName: '경제학원론', day: '월', startTime: '09:00', endTime: '10:30'),
    ClassSession(
        courseName: '심리학개론', day: '화', startTime: '11:00', endTime: '12:30'),
    ClassSession(courseName: '통계', day: '월', startTime: '13:00'), // 종료 없음
  ];

  // 2026-07-20은 월요일.
  final mon = DateTime(2026, 7, 20);

  test('수업 시간대 안이면 그 과목으로 분류', () {
    expect(subjectAt(table, mon.add(const Duration(hours: 9, minutes: 30))),
        '경제학원론');
  });

  test('요일이 다르면 매칭 안 됨', () {
    // 화요일 09:30 → 월요일 경제학원론과 겹치지 않음
    final tue = DateTime(2026, 7, 21, 9, 30);
    expect(subjectAt(table, tue), '');
  });

  test('수업 시간 밖이면 빈 문자열', () {
    expect(subjectAt(table, mon.add(const Duration(hours: 8))), '');
  });

  test('종료 시간 없으면 90분으로 간주', () {
    // 13:00 시작, 종료 미기재 → 14:30까지 유효. 14:00은 포함.
    expect(subjectAt(table, mon.add(const Duration(hours: 14))), '통계');
    // 15:00은 범위 밖.
    expect(subjectAt(table, mon.add(const Duration(hours: 15))), '');
  });
}

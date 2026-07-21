import 'package:flutter_test/flutter_test.dart';

import 'package:border/models/enums.dart';
import 'package:border/models/review_schedule.dart';
import 'package:border/models/unit.dart';
import 'package:border/services/review/review_engine.dart';

/// v5 스펙 10장 "복습 재노출 알고리즘"을 검증한다.
void main() {
  const engine = ReviewEngine(); // 간격 1일
  final today = DateTime(2026, 7, 21, 10);
  final tomorrow = today.add(const Duration(days: 1));

  ReviewSchedule sched({int stage = 1, int attempt = 0, DateTime? due}) =>
      ReviewSchedule(
        unitId: 'u',
        stage: stage,
        dueDate: due ?? today,
        attemptCount: attempt,
      );

  Unit unit({bool learned = false, DateTime? created}) => Unit(
        id: 'u',
        sourceType: SourceType.recording,
        createdAt: created ?? today,
        content: '내용',
        learned: learned,
      );

  group('onLearned', () {
    test('학습 완료 → 1단계, 다음날 마감', () {
      final s = engine.onLearned('u', now: today);
      expect(s.stage, 1);
      expect(s.status, 'pending');
      expect(s.dueDate, tomorrow);
    });
  });

  group('apply — 정답 전진', () {
    test('1단계 정답 → 2단계(다음날)', () {
      final s = engine.apply(sched(stage: 1), true, now: today);
      expect(s.stage, 2);
      expect(s.dueDate, tomorrow);
      expect(s.attemptCount, 0);
    });

    test('2단계 정답 → 3단계', () {
      expect(engine.apply(sched(stage: 2), true, now: today).stage, 3);
    });

    test('3단계 정답 → 복습 완료', () {
      final s = engine.apply(sched(stage: 3), true, now: today);
      expect(s.status, 'completed');
    });
  });

  group('apply — 오답 한 단계 후퇴', () {
    test('1단계 오답 → 1단계 유지(더 내려가지 않음)', () {
      final s = engine.apply(sched(stage: 1), false, now: today);
      expect(s.stage, 1);
      expect(s.attemptCount, 1);
      expect(s.dueDate, tomorrow);
    });

    test('2단계 오답 → 1단계로 후퇴', () {
      expect(engine.apply(sched(stage: 2), false, now: today).stage, 1);
    });

    test('3단계 오답 → 2단계로 후퇴', () {
      expect(engine.apply(sched(stage: 3), false, now: today).stage, 2);
    });
  });

  group('선정/집계', () {
    test('마감 전·완료 항목은 복습 대상에서 제외, 낮은 단계 우선', () {
      final all = [
        sched(stage: 3, due: today),
        sched(stage: 1, due: today),
        sched(stage: 2, due: tomorrow), // 아직 마감 전
        ReviewSchedule(
            unitId: 'done', stage: 3, dueDate: today, status: 'completed'),
      ];
      final due = engine.due(all, now: today);
      expect(due.map((s) => s.stage), [1, 3]); // 낮은 단계 우선, 미래·완료 제외
    });

    test('pendingCount = 신규 단원 + 마감 복습', () {
      final units = [unit(), unit(learned: true)];
      final schedules = [sched(stage: 1, due: today)];
      expect(engine.pendingCount(units, schedules, now: today), 2);
    });
  });
}

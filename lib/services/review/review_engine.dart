import '../../models/review_schedule.dart';
import '../../models/unit.dart';

/// 3단계 간격 반복 복습 엔진(v5 스펙 10장).
///
/// 규칙: 단원 학습 완료 → 1단계 등록(다음날). 정답이면 한 단계 전진(다음날),
/// 오답이면 한 단계 후퇴(다음날, 1단계는 그 자리 유지). 3단계 정답이면 완료.
class ReviewEngine {
  const ReviewEngine({this.reviewInterval = const Duration(days: 1)});

  /// 다음 복습까지의 간격. 스펙은 "다음날"(D+1).
  /// (데모에서 즉시 확인하려면 Duration(minutes: 1) 등으로 바꾸면 된다.)
  final Duration reviewInterval;

  static const int maxStage = 3;

  /// 학습을 마친 단원을 1단계 복습으로 등록한다.
  ReviewSchedule onLearned(String unitId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return ReviewSchedule(
      unitId: unitId,
      stage: 1,
      dueDate: at.add(reviewInterval),
    );
  }

  /// 오늘 복습할 항목: 마감(pending & due<=today)만, 낮은 단계 우선.
  List<ReviewSchedule> due(List<ReviewSchedule> all, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final list = all
        .where((s) => s.isPending && !s.dueDate.isAfter(at))
        .toList()
      ..sort((a, b) => a.stage.compareTo(b.stage));
    return list;
  }

  /// 한 단계 응답을 반영한다.
  /// 정답: 마지막 단계면 완료, 아니면 다음 단계(다음날).
  /// 오답: 한 단계 후퇴(다음날). 1단계는 그대로 유지.
  ReviewSchedule apply(ReviewSchedule s, bool correct, {DateTime? now}) {
    final at = now ?? DateTime.now();
    if (correct) {
      if (s.stage >= maxStage) {
        return s.copyWith(status: 'completed');
      }
      return s.copyWith(
        stage: s.stage + 1,
        dueDate: at.add(reviewInterval),
        attemptCount: 0,
      );
    }
    return s.copyWith(
      stage: (s.stage - 1).clamp(1, maxStage),
      dueDate: at.add(reviewInterval),
      attemptCount: s.attemptCount + 1,
    );
  }

  /// 아직 학습하지 않은 신규 단원(만든 순서대로).
  List<Unit> newUnits(List<Unit> all) {
    final list = all.where((u) => !u.learned).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 오늘 남은 학습·복습 항목 수(신규 단원 + 마감 복습).
  int pendingCount(
    List<Unit> units,
    List<ReviewSchedule> schedules, {
    DateTime? now,
  }) {
    return newUnits(units).length + due(schedules, now: now).length;
  }
}

import 'package:flutter/foundation.dart';

import '../data/review_repository.dart';
import '../data/unit_repository.dart';
import '../models/quiz.dart';
import '../models/review_schedule.dart';
import '../models/unit.dart';
import '../services/review/review_engine.dart';

enum StepKind { learn, review }

/// 세션의 한 걸음: 특정 단원을 학습하거나(신규), 특정 단계로 복습한다.
class LearnStep {
  final Unit unit;
  final StepKind kind;

  /// 복습 스텝일 때의 스케줄(현재 단계·재시도 횟수 포함).
  final ReviewSchedule? schedule;

  const LearnStep(this.unit, this.kind, {this.schedule});

  int get stage => schedule?.stage ?? 0;
}

/// "학습하기" 세션을 관장하는 컨트롤러(v5 스펙 4·10장).
///
/// 홈 진입 시 마감된 복습을 낮은 단계 우선으로 먼저 제시하고(경우2), 그다음
/// 아직 학습하지 않은 신규 단원을 학습한다(경우1). 복습 응답은 3단계 상태
/// 머신([ReviewEngine])으로 반영한다.
class LearnController extends ChangeNotifier {
  LearnController({
    required this.unitRepo,
    required this.reviewRepo,
    required this.engine,
  });

  final UnitRepository unitRepo;
  final ReviewRepository reviewRepo;
  final ReviewEngine engine;

  final List<LearnStep> _steps = [];
  int _index = 0;
  bool _hasReview = false;

  int get index => _index;
  int get total => _steps.length;
  LearnStep? get current => _index < _steps.length ? _steps[_index] : null;
  bool get isEmpty => _steps.isEmpty;
  bool get isFinished => _steps.isNotEmpty && _index >= _steps.length;
  bool get hasReview => _hasReview;

  void start({DateTime? now}) {
    final due = engine.due(reviewRepo.all(), now: now);
    _hasReview = due.isNotEmpty;
    _steps.clear();

    // 복습 먼저(낮은 단계 우선).
    for (final s in due) {
      final u = unitRepo.get(s.unitId);
      if (u != null) _steps.add(LearnStep(u, StepKind.review, schedule: s));
    }
    // 그다음 신규 단원 학습.
    for (final u in engine.newUnits(unitRepo.all())) {
      _steps.add(LearnStep(u, StepKind.learn));
    }

    _index = 0;
    notifyListeners();
  }

  /// 이번 복습 스텝에 낼 문항(재시도 시 같은 단계의 다른 문항으로 교체).
  Quiz? quizForCurrent() {
    final step = current;
    if (step == null || step.schedule == null) return null;
    final pool = step.unit.quizzesForStage(step.schedule!.stage);
    if (pool.isEmpty) return null;
    return pool[step.schedule!.attemptCount % pool.length];
  }

  /// 신규 단원 학습 완료 → 학습 기록 + 1단계 복습 등록.
  Future<void> completeLearn({DateTime? now}) async {
    final step = current;
    if (step != null && step.kind == StepKind.learn && !step.unit.learned) {
      final at = now ?? DateTime.now();
      await unitRepo.save(step.unit.copyWith(learned: true, learnedDate: at));
      await reviewRepo.save(engine.onLearned(step.unit.id, now: at));
    }
    _advance();
  }

  /// 복습 응답을 3단계 상태 머신에 반영한다.
  Future<void> answerReview(bool correct, {DateTime? now}) async {
    final step = current;
    if (step?.schedule != null) {
      await reviewRepo.save(engine.apply(step!.schedule!, correct, now: now));
    }
    _advance();
  }

  void _advance() {
    _index += 1;
    notifyListeners();
  }
}

/// 한 단원의 복습 진행 상태(스펙의 ReviewSchedule).
///
/// 단원을 학습하면 1단계로 등록되고, 정답이면 다음 단계로 전진(다음날),
/// 오답이면 한 단계 후퇴(다음날)한다. 3단계까지 통과하면 complete.
/// (상세 규칙: v5 스펙 10장)
class ReviewSchedule {
  final String unitId;

  /// 현재 단계(1=키워드+뜻, 2=OX, 3=유사문제).
  final int stage;

  /// 다음 복습 예정일. 이 날짜가 지나면 복습 대상.
  final DateTime dueDate;

  /// 'pending' | 'completed'.
  final String status;

  /// 오답으로 재노출된 횟수(유사 문제 변형 출제 인덱스로도 쓴다).
  final int attemptCount;

  const ReviewSchedule({
    required this.unitId,
    this.stage = 1,
    required this.dueDate,
    this.status = 'pending',
    this.attemptCount = 0,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  ReviewSchedule copyWith({
    int? stage,
    DateTime? dueDate,
    String? status,
    int? attemptCount,
  }) =>
      ReviewSchedule(
        unitId: unitId,
        stage: stage ?? this.stage,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
      );

  Map<String, dynamic> toMap() => {
        'unitId': unitId,
        'stage': stage,
        'dueDate': dueDate.toIso8601String(),
        'status': status,
        'attemptCount': attemptCount,
      };

  factory ReviewSchedule.fromMap(Map<dynamic, dynamic> m) => ReviewSchedule(
        unitId: m['unitId'] as String,
        stage: m['stage'] as int? ?? 1,
        dueDate: DateTime.parse(m['dueDate'] as String),
        status: m['status'] as String? ?? 'pending',
        attemptCount: m['attemptCount'] as int? ?? 0,
      );
}

/// 복습 문항(스펙의 Quiz). 단계별로 성격이 다르다.
///
/// - stage 2: O/X 퀴즈 → [choices] = ['O','X'].
/// - stage 3: 유사(응용) 문제 → [choices] = 선택지 여러 개.
/// (stage 1은 키워드 카드로 직접 확인하므로 Quiz를 쓰지 않는다.)
///
/// 정답은 [answer]로 [choices]의 인덱스를 가리킨다. 재노출 시 같은 단계의
/// 다른 문항을 골라("유사 문제로 교체") 암기 통과를 막는다.
class Quiz {
  final int stage;
  final String question;
  final List<String> choices;
  final int answer;

  const Quiz({
    required this.stage,
    required this.question,
    required this.choices,
    required this.answer,
  });

  bool isCorrect(int picked) => picked == answer;

  Map<String, dynamic> toMap() =>
      {'stage': stage, 'question': question, 'choices': choices, 'answer': answer};

  factory Quiz.fromMap(Map<dynamic, dynamic> m) => Quiz(
        stage: m['stage'] as int? ?? 2,
        question: m['question'] as String? ?? '',
        choices:
            (m['choices'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        answer: m['answer'] as int? ?? 0,
      );
}

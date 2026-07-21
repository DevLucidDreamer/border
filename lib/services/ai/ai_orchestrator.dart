import '../../models/enums.dart';
import '../../models/keyword_card.dart';
import '../../models/quiz.dart';
import '../../models/unit.dart';
import 'pipeline_stages.dart';

/// 자료 1건을 학습 단원 하나로 만드는 오케스트레이터(v5 스펙 8·9장).
///
/// 원문 → 쉬운글 → (키워드·복습 문항 + 쉬운글 음성). 스펙대로 내용을 여러
/// 개념으로 쪼개지 않고, 자료 1건 = 단원 1개로 묶는다.
class AiOrchestrator {
  AiOrchestrator({
    required this.summarizer,
    required this.contentBuilder,
    required this.tts,
  });

  final Summarizer summarizer;
  final UnitContentBuilder contentBuilder;
  final AudioSummarizer tts;

  Future<Unit> run({
    required String unitId,
    required SourceType sourceType,
    required DateTime createdAt,
    required String rawTranscript,
    int unitNo = 1,
    String subjectName = '',
    void Function(LectureStatus status)? onStatus,
  }) async {
    // ① 쉬운글 정리.
    onStatus?.call(LectureStatus.summarizing);
    final easyText = await summarizer.summarize(rawTranscript);

    // ② 키워드 + 2·3단계 복습 문항.
    onStatus?.call(LectureStatus.buildingContent);
    final draft = await contentBuilder.build(easyText);

    // ③ 쉬운글 음성.
    onStatus?.call(LectureStatus.generatingMedia);
    final audioPath = await tts.synthesize(easyText, lectureId: unitId);

    final keywordCards = [
      for (final k in draft.keywords)
        KeywordCard(keyword: k.keyword, meaning: k.meaning),
    ];

    final quizzes = <Quiz>[
      for (final ox in draft.oxQuizzes)
        Quiz(
          stage: 2,
          question: ox.statement,
          choices: const ['O', 'X'],
          answer: ox.answer ? 0 : 1,
        ),
      for (final a in draft.appliedQuizzes)
        Quiz(stage: 3, question: a.question, choices: a.choices, answer: a.answer),
    ];

    return Unit(
      id: unitId,
      sourceType: sourceType,
      createdAt: createdAt,
      unitNo: unitNo,
      subjectName: subjectName,
      content: easyText,
      audioPath: audioPath,
      keywordCards: keywordCards,
      quizzes: quizzes,
    );
  }
}

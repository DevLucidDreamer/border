import 'package:flutter/foundation.dart';

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
    required this.imageGenerator,
  });

  final Summarizer summarizer;
  final UnitContentBuilder contentBuilder;
  final AudioSummarizer tts;
  final ImageGenerator imageGenerator;

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
    debugPrint('[AI] rawTranscript len=${rawTranscript.length} '
        'easyText len=${easyText.trim().length}');
    // 요약이 비면(모델 빈 응답 등) 이후 문항·음성이 모두 무의미하고,
    // 빈 글이 TTS로 넘어가면 API가 400을 낸다. 여기서 분명히 끊는다.
    if (easyText.trim().isEmpty) {
      throw Exception('AI가 내용을 정리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }

    // ② 키워드 + 2·3단계 복습 문항.
    onStatus?.call(LectureStatus.buildingContent);
    final draft = await contentBuilder.build(easyText);

    // ③ 쉬운글 음성 + ④ 키워드 삽화(동시 생성으로 대기 시간을 줄인다).
    onStatus?.call(LectureStatus.generatingMedia);
    final audioFuture = tts.synthesize(easyText, lectureId: unitId);
    final cardsFuture = Future.wait([
      for (var i = 0; i < draft.keywords.length; i++)
        _cardWithImage(draft.keywords[i], unitId, i),
    ]);
    final audioPath = await audioFuture;
    final keywordCards = await cardsFuture;

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

  /// 키워드 하나를 삽화와 함께 카드로 만든다. 이미지 생성이 실패해도(키 없음·
  /// 네트워크 오류) 전체 파이프라인을 막지 않고 그림 없는 카드로 넘어간다.
  Future<KeywordCard> _cardWithImage(
      KeywordDraft k, String unitId, int index) async {
    String? imagePath;
    try {
      imagePath = await imageGenerator.illustrate(k.keyword, k.meaning,
          unitId: unitId, index: index);
    } catch (_) {
      // 삽화는 부가 요소 — 실패 시 플레이스홀더로 대체된다.
    }
    return KeywordCard(
        keyword: k.keyword, meaning: k.meaning, imagePath: imagePath);
  }
}

// AI 파이프라인의 각 전문 단계 인터페이스(v5 스펙 8장).
//
// 원문 → 쉬운글 재구성(①) → 키워드·복습 문항 생성(②) → 쉬운글 음성(③).
// 스펙 9장대로 자료 1건 = 단원 1개이므로 별도 단원 분할 로직은 없다.
// 각 인터페이스는 목/실제 API 구현으로 교체할 수 있다.

/// ① 원문을 쉬운 언어의 스토리텔링 본문으로 재구성한다.
abstract class Summarizer {
  Future<String> summarize(String rawTranscript);
}

/// ② 쉬운글에서 키워드(+뜻)와 2·3단계 복습 문항을 만든다.
abstract class UnitContentBuilder {
  Future<UnitContentDraft> build(String easyText);
}

/// ③ 쉬운글을 듣기 쉬운 음성(TTS)으로 바꾼다. 반환은 로컬 경로(불가 시 null).
abstract class AudioSummarizer {
  Future<String?> synthesize(String text, {required String lectureId});
}

/// [UnitContentBuilder]의 산출물: 키워드 카드 + O/X + 유사문제 초안.
class UnitContentDraft {
  final List<KeywordDraft> keywords;

  /// 2단계 O/X 문장들(정답 포함).
  final List<OxDraft> oxQuizzes;

  /// 3단계 유사(응용) 선택형 문항들.
  final List<AppliedDraft> appliedQuizzes;

  const UnitContentDraft({
    this.keywords = const [],
    this.oxQuizzes = const [],
    this.appliedQuizzes = const [],
  });
}

class KeywordDraft {
  final String keyword;
  final String meaning;
  const KeywordDraft({required this.keyword, required this.meaning});
}

class OxDraft {
  final String statement;
  final bool answer; // true=O(맞음), false=X(틀림)
  const OxDraft({required this.statement, required this.answer});
}

class AppliedDraft {
  final String question;
  final List<String> choices;
  final int answer; // choices의 정답 인덱스
  const AppliedDraft({
    required this.question,
    required this.choices,
    required this.answer,
  });
}

import '../pipeline_stages.dart';

/// API 키 없이 전체 학습 루프를 시연하기 위한 목 구현들.
/// 실제 서비스에서는 각 클래스를 외부 AI API 호출 구현으로 교체한다.

/// 쉬운 글 정리 목.
class MockSummarizer implements Summarizer {
  @override
  Future<String> summarize(String rawTranscript) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return '''
오늘 배운 내용을 쉽게 정리해 볼게요.

물건을 사고 싶어 하는 마음을 "수요"라고 해요.
값이 오르면 사람들은 덜 사려고 해요. 이걸 "수요의 법칙"이라고 불러요.

물건을 팔고 싶어 하는 마음은 "공급"이에요.
값이 오르면 파는 사람은 더 많이 팔고 싶어 해요.

사려는 양과 팔려는 양이 딱 맞는 지점이 있어요.
그때의 값을 "균형 가격"이라고 해요.
''';
  }
}

/// 키워드 + 2·3단계 복습 문항 목.
class MockUnitContentBuilder implements UnitContentBuilder {
  @override
  Future<UnitContentDraft> build(String easyText) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const UnitContentDraft(
      keywords: [
        KeywordDraft(keyword: '수요', meaning: '물건을 사고 싶어 하는 마음이에요.'),
        KeywordDraft(keyword: '공급', meaning: '물건을 팔고 싶어 하는 마음이에요.'),
        KeywordDraft(
            keyword: '균형 가격', meaning: '사려는 양과 팔려는 양이 딱 맞는 값이에요.'),
      ],
      oxQuizzes: [
        OxDraft(statement: '수요는 물건을 사고 싶어 하는 마음이다.', answer: true),
        OxDraft(statement: '값이 오르면 사람들은 물건을 더 많이 사려고 한다.', answer: false),
        OxDraft(statement: '공급은 물건을 팔고 싶어 하는 마음이다.', answer: true),
      ],
      appliedQuizzes: [
        AppliedDraft(
          question: '값이 오를 때 소비자의 행동으로 알맞은 것은?',
          choices: ['덜 사려고 한다', '더 많이 사려고 한다', '아무 변화가 없다'],
          answer: 0,
        ),
        AppliedDraft(
          question: '"균형 가격"을 가장 잘 설명한 것은?',
          choices: [
            '사려는 양과 팔려는 양이 맞는 값',
            '가장 비싼 값',
            '가장 싼 값',
          ],
          answer: 0,
        ),
      ],
    );
  }
}

/// 오디오(TTS) 목: 실제 음성 파일 대신 null.
class MockAudioSummarizer implements AudioSummarizer {
  @override
  Future<String?> synthesize(String text, {required String lectureId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return null;
  }
}

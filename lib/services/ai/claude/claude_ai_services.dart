import 'dart:convert';

import '../pipeline_stages.dart';
import 'claude_client.dart';

/// 경계선지능 학습자를 위한 "쉬운 글" 작성 원칙. 모든 단계가 공유한다.
const _easyLanguageRules = '''
너는 경계선지능 청년(대학생)의 학습을 돕는 도우미야. 다음 원칙을 반드시 지켜:
- 한 문장은 짧게. 한 문장에 한 가지 내용만 담아.
- 주어와 서술어의 관계를 분명하게 써.
- 어려운 용어는 그대로 쓰지 말고, 그 개념이 쓰이는 상황을 풀어서 설명해.
- 추상적인 내용은 일상적인 예시로 바꿔서 설명해.
- 따뜻하고 다정한 말투를 써. 학습자를 격려해.
- 반말이 아니라 친근한 존댓말(~해요체)을 써.
''';

/// ① 원문 → 쉬운 언어의 스토리텔링 본문.
class ClaudeSummarizer implements Summarizer {
  ClaudeSummarizer(this._client);
  final ClaudeClient _client;

  @override
  Future<String> summarize(String rawTranscript) {
    return _client.complete(
      system: _easyLanguageRules,
      maxTokens: 2048,
      userPrompt: '''
아래는 강의 내용이야. 경계선지능 학습자가 이해하기 쉽도록 핵심을 다시 정리해줘.
단순 요약이 아니라, 이야기하듯 자연스럽게 풀어서 설명해줘.
결과는 정리된 본문 글만 출력해. 다른 말은 붙이지 마.

[강의 내용]
$rawTranscript''',
    );
  }
}

/// ② 쉬운글 → 키워드(+뜻) · 2단계 O/X · 3단계 유사문제.
class ClaudeUnitContentBuilder implements UnitContentBuilder {
  ClaudeUnitContentBuilder(this._client);
  final ClaudeClient _client;

  @override
  Future<UnitContentDraft> build(String easyText) async {
    final text = await _client.complete(
      system: _easyLanguageRules,
      maxTokens: 3072,
      userPrompt: '''
아래 학습 정리로 복습 자료를 만들어줘. 세 가지를 채워:
1) keywords: 핵심 키워드 3~6개. 각 항목은 {keyword, meaning(짧고 쉬운 뜻)}.
2) ox: O/X 문장 3~5개. 각 항목은 {statement, answer(맞으면 true, 틀리면 false)}.
3) applied: 유사(응용) 선택형 문제 2~4개. 각 항목은 {question, choices(2~4개 배열), answer(정답 인덱스, 0부터)}.
반드시 아래 JSON 객체 형식으로만 출력해. 코드블록·설명 금지.
{
  "keywords": [{"keyword": "", "meaning": ""}],
  "ox": [{"statement": "", "answer": true}],
  "applied": [{"question": "", "choices": ["", ""], "answer": 0}]
}

[학습 정리]
$easyText''',
    );
    final m = jsonDecode(_extractJsonObject(text)) as Map<String, dynamic>;
    return UnitContentDraft(
      keywords: ((m['keywords'] as List<dynamic>?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map((k) => KeywordDraft(
                keyword: (k['keyword'] ?? '') as String,
                meaning: (k['meaning'] ?? '') as String,
              ))
          .where((k) => k.keyword.isNotEmpty)
          .toList(),
      oxQuizzes: ((m['ox'] as List<dynamic>?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map((o) => OxDraft(
                statement: (o['statement'] ?? '') as String,
                answer: (o['answer'] as bool?) ?? true,
              ))
          .where((o) => o.statement.isNotEmpty)
          .toList(),
      appliedQuizzes: ((m['applied'] as List<dynamic>?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map((a) => AppliedDraft(
                question: (a['question'] ?? '') as String,
                choices: ((a['choices'] as List<dynamic>?) ?? [])
                    .map((e) => e.toString())
                    .toList(),
                answer: (a['answer'] as int?) ?? 0,
              ))
          .where((a) => a.question.isNotEmpty && a.choices.length >= 2)
          .toList(),
    );
  }
}

/// 모델 응답에서 JSON 객체 부분만 안전하게 추출한다(코드펜스·앞뒤 설명 제거).
String _extractJsonObject(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    t = t.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '').trim();
  }
  final start = t.indexOf('{');
  final end = t.lastIndexOf('}');
  if (start == -1 || end == -1 || end < start) {
    throw Exception('AI 응답을 읽지 못했어요: $text');
  }
  return t.substring(start, end + 1);
}

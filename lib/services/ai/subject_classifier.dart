import 'claude/claude_client.dart';

/// 업로드한 자료(음성·PDF)의 내용을 보고 어느 과목인지 분류한다.
/// (녹음은 시각으로 분류하므로 이건 업로드 경로에서만 쓴다.)
abstract class SubjectClassifier {
  /// [text] 내용에 가장 알맞은 과목명을 [subjects] 중에서 고른다(없으면 '').
  Future<String> classify(String text, List<String> subjects);
}

/// Claude로 내용을 과목에 매칭한다.
class ClaudeSubjectClassifier implements SubjectClassifier {
  ClaudeSubjectClassifier(this._client);
  final ClaudeClient _client;

  @override
  Future<String> classify(String text, List<String> subjects) async {
    if (subjects.isEmpty) return '';
    final sample = text.length > 1500 ? text.substring(0, 1500) : text;
    final answer = await _client.complete(
      system: '너는 학습 자료를 과목으로 분류하는 도우미야.',
      maxTokens: 64,
      userPrompt: '''
아래 학습 내용에 가장 알맞은 과목을 후보 중에서 딱 하나만 골라, 과목명만 그대로 출력해.
해당하는 과목이 없으면 "없음"이라고만 출력해. 다른 말은 붙이지 마.

[후보 과목]
${subjects.join(', ')}

[학습 내용]
$sample''',
    );
    final a = answer.trim();
    // 응답에 후보 과목명이 들어 있으면 그걸 채택한다.
    for (final s in subjects) {
      if (a.contains(s)) return s;
    }
    return '';
  }
}

/// 키 없이 시연하기 위한 목: 첫 과목으로 분류.
class MockSubjectClassifier implements SubjectClassifier {
  @override
  Future<String> classify(String text, List<String> subjects) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return subjects.isEmpty ? '' : subjects.first;
  }
}

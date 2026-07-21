import 'dart:convert';

import 'package:http/http.dart' as http;

/// Anthropic Messages API(`POST /v1/messages`)를 감싼 얇은 클라이언트.
///
/// Dart에는 공식 Anthropic SDK가 없어 raw HTTP로 호출한다. 각 AI 단계
/// (정리·복습 문항·전략)가 이 클라이언트를 공유한다.
class ClaudeClient {
  ClaudeClient({
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _version = '2023-06-01';

  /// system + user 프롬프트로 한 번의 completion을 받아 본문 텍스트를 돌려준다.
  Future<String> complete({
    required String system,
    required String userPrompt,
    int maxTokens = 2048,
  }) {
    return _send(maxTokens: maxTokens, system: system, content: userPrompt);
  }

  /// 이미지 한 장 + 프롬프트로 비전 요청을 보낸다(예: 시간표 OCR).
  /// [mediaType]은 `image/png`·`image/jpeg` 등.
  Future<String> completeVision({
    required String system,
    required String userPrompt,
    required List<int> imageBytes,
    required String mediaType,
    int maxTokens = 2048,
  }) {
    return _send(maxTokens: maxTokens, system: system, content: [
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mediaType,
          'data': base64Encode(imageBytes),
        },
      },
      {'type': 'text', 'text': userPrompt},
    ]);
  }

  /// 실제 요청 전송 + 응답 텍스트 추출(문자열/블록 배열 content 공용).
  Future<String> _send({
    required int maxTokens,
    required String system,
    required Object content,
  }) async {
    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _version,
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Claude API 오류 ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final blocks = body['content'] as List<dynamic>;
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block is Map && block['type'] == 'text') {
        buffer.write(block['text'] as String);
      }
    }
    return buffer.toString().trim();
  }

  void dispose() => _http.close();
}

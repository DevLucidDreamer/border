import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// PDF 한 개 + 프롬프트로 문서를 읽어 전사(스캔·이미지 PDF도 vision OCR).
  /// document 블록은 텍스트 블록보다 앞에 둔다(베타 헤더 불필요).
  Future<String> completeDocument({
    required String system,
    required String userPrompt,
    required List<int> pdfBytes,
    int maxTokens = 8192,
  }) {
    return _send(maxTokens: maxTokens, system: system, content: [
      {
        'type': 'document',
        'source': {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': base64Encode(pdfBytes),
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
        // Sonnet 5는 thinking 미지정 시 adaptive 사고가 켜져 max_tokens를
        // 사고에 소진하고 답변이 비어 나온다. 정리·문항·OCR은 사고 불필요.
        'thinking': {'type': 'disabled'},
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
    final out = buffer.toString().trim();
    if (out.isEmpty) {
      // 빈 응답 진단: stop_reason·블록 타입을 남긴다.
      final types = blocks
          .map((b) => b is Map ? b['type'] : b.runtimeType)
          .toList();
      debugPrint('[Claude] EMPTY text. stop_reason=${body['stop_reason']} '
          'blocks=$types usage=${body['usage']}');
    }
    return out;
  }

  void dispose() => _http.close();
}

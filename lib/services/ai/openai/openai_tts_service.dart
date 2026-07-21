import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../pipeline_stages.dart';

/// OpenAI `gpt-4o-mini-tts`로 정리된 쉬운 글을 자연스러운 음성으로 읽어준다.
///
/// 긴 글 읽기 부담을 줄이는 오디오 요약(기획서 세 번째 요소). 입력은 반드시
/// "정리된 쉬운 글"(easySummary)이며 원문/녹음본이 아니다. `instructions`로
/// 경계선지능 학습자에게 맞는 말투(다정하고 또렷하게, 조금 천천히)를 지시한다.
class OpenAiTtsService implements AudioSummarizer {
  OpenAiTtsService({
    required this.apiKey,
    this.model = 'gpt-4o-mini-tts',
    this.voice = 'coral',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final String voice;
  final http.Client _http;

  static const _endpoint = 'https://api.openai.com/v1/audio/speech';

  /// TTS 입력 글자 수 상한(초과 시 잘라서 요청).
  static const _maxChars = 4096;

  /// 느린학습자를 위한 말투 지시.
  static const _instructions =
      '다정하고 또렷한 목소리로, 조금 천천히 읽어 주세요. 학습자를 격려하는 따뜻한 느낌으로 말해 주세요.';

  @override
  Future<String?> synthesize(String easySummary,
      {required String lectureId}) async {
    final text = easySummary.length > _maxChars
        ? easySummary.substring(0, _maxChars)
        : easySummary;

    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'voice': voice,
        'input': text,
        'instructions': _instructions,
        'response_format': 'mp3',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('TTS API 오류 ${res.statusCode}: ${res.body}');
    }

    // 응답 본문은 mp3 바이트. 로컬에 저장하고 경로를 돌려준다.
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final path = '${audioDir.path}/tts_$lectureId.mp3';
    await File(path).writeAsBytes(res.bodyBytes);
    return path;
  }

  void dispose() => _http.close();
}

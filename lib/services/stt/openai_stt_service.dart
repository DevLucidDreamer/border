import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import 'stt_service.dart';

/// OpenAI 음성 인식(`/v1/audio/transcriptions`)으로 음성을 텍스트로 바꾼다.
///
/// 추천 조합(B)의 STT 모델은 `whisper-1`. 변환된 원문은 학습자에게 직접
/// 노출하지 않고 이후 AI 정리 단계의 입력으로만 쓴다.
class OpenAiSttService implements SttService {
  OpenAiSttService({
    required this.apiKey,
    this.model = 'whisper-1',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  // 웹은 프록시(/api/openai), 네이티브는 실제 도메인.
  static String get _endpoint =>
      '${AppConfig.openaiBase}/v1/audio/transcriptions';

  /// 이 값보다 무음 확률(no_speech_prob)이 높은 구간은 실제 말이 아니라고 보고
  /// 버린다. Whisper가 무음에서 지어내는 환청(hallucination)을 걸러 내는 기준.
  static const _noSpeechThreshold = 0.6;

  @override
  Future<String> transcribe(String? audioFilePath,
      {List<int>? bytes, String filename = 'audio.m4a'}) async {
    if (bytes == null && audioFilePath == null) {
      throw Exception('변환할 음성 파일이 없어요.');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = model
      ..fields['language'] = 'ko'
      // 구간별 no_speech_prob를 받아 무음 환청을 걸러내고, 지어내기를 줄이려
      // temperature를 0으로 고정한다.
      ..fields['response_format'] = 'verbose_json'
      ..fields['temperature'] = '0'
      // 웹은 파일 경로가 없어 바이트로, 네이티브는 파일 경로로 첨부한다.
      ..files.add(bytes != null
          ? http.MultipartFile.fromBytes('file', bytes, filename: filename)
          : await http.MultipartFile.fromPath('file', audioFilePath!));

    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception('STT API 오류 ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return _speechOnly(body);
  }

  /// 실제 말이 담긴 구간의 텍스트만 이어 붙인다. 무음 구간(환청)은 제외한다.
  /// 구간 정보가 없으면 전체 텍스트를 그대로 쓴다.
  String _speechOnly(Map<String, dynamic> body) {
    final segments = body['segments'] as List<dynamic>?;
    if (segments == null || segments.isEmpty) {
      return (body['text'] as String? ?? '').trim();
    }
    return segments
        .cast<Map<String, dynamic>>()
        .where((s) => (s['no_speech_prob'] as num? ?? 0) <= _noSpeechThreshold)
        .map((s) => (s['text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty)
        .join(' ')
        .trim();
  }

  void dispose() => _http.close();
}

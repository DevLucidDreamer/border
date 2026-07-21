import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../pipeline_stages.dart';

/// 네이버 CLOVA Voice(Premium)로 정리된 쉬운 글을 음성으로 읽어준다.
///
/// 긴 글 읽기의 부담을 줄이기 위한 오디오 요약이다(기획서 세 번째 요소).
/// 입력은 반드시 "정리된 쉬운 글"이며, 원문/녹음본이 아니다.
class ClovaVoiceTtsService implements AudioSummarizer {
  ClovaVoiceTtsService({
    required this.clientId,
    required this.clientSecret,
    this.speaker = 'nara',
    // 느린학습자를 위해 살짝 느리게(양수일수록 느림, 범위 -5~5).
    this.speed = 1,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String clientId;
  final String clientSecret;
  final String speaker;
  final int speed;
  final http.Client _http;

  static const _endpoint =
      'https://naveropenapi.apigw.ntruss.com/tts-premium/v1/tts';

  /// CLOVA Voice 한 요청의 최대 글자 수.
  static const _maxChars = 2000;

  @override
  Future<String?> synthesize(String easySummary,
      {required String lectureId}) async {
    final text =
        easySummary.length > _maxChars ? easySummary.substring(0, _maxChars) : easySummary;

    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-NCP-APIGW-API-KEY-ID': clientId,
        'X-NCP-APIGW-API-KEY': clientSecret,
      },
      body: {
        'speaker': speaker,
        'text': text,
        'speed': '$speed',
        'format': 'mp3',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('CLOVA Voice 오류 ${res.statusCode}: ${res.body}');
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

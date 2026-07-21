import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../pipeline_stages.dart';

/// OpenAI 이미지 생성(`/v1/images/generations`)으로 키워드를 나타내는
/// 쉬운 삽화 한 장을 만든다. STT·TTS와 같은 OpenAI 키를 공유한다.
///
/// 경계선지능 학습자를 위해 글자 없이 단순하고 따뜻한 그림을 요청한다.
/// gpt-image-1은 항상 b64_json으로 응답하므로 `response_format`을 보내지 않는다
/// (보내면 400). 시연 속도·비용을 위해 quality=low를 기본으로 한다.
class OpenAiImageService implements ImageGenerator {
  OpenAiImageService({
    required this.apiKey,
    this.model = 'gpt-image-1',
    this.size = '1024x1024',
    this.quality = 'low',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final String size;
  final String quality;
  final http.Client _http;

  static const _endpoint = 'https://api.openai.com/v1/images/generations';

  @override
  Future<String?> illustrate(
    String keyword,
    String meaning, {
    required String unitId,
    required int index,
  }) async {
    final prompt = '''
"$keyword"($meaning) 개념을 나타내는 단순하고 따뜻한 삽화.
부드러운 파스텔 색, 평면적인 플랫 일러스트 스타일. 글자·숫자·문자는 절대 넣지 마세요.
느린 학습자도 한눈에 이해할 수 있게 대상 하나만 크고 또렷하게 그려 주세요.''';

    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'n': 1,
        'size': size,
        'quality': quality,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('이미지 API 오류 ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final b64 = (body['data'] as List).first['b64_json'] as String?;
    if (b64 == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final path = '${imgDir.path}/img_${unitId}_$index.png';
    await File(path).writeAsBytes(base64Decode(b64));
    return path;
  }

  void dispose() => _http.close();
}

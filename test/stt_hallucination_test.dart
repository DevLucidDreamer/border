import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:border/services/stt/openai_stt_service.dart';

/// 무음 구간에서 Whisper가 지어내는 환청을 STT가 걸러내는지 검증한다.
void main() {
  late File audio;

  setUp(() async {
    audio = File('${Directory.systemTemp.path}/stt_test.m4a');
    await audio.writeAsBytes([0, 1, 2, 3]); // MultipartFile.fromPath용 더미
  });

  tearDown(() async {
    if (await audio.exists()) await audio.delete();
  });

  http.Client clientReturning(Map<String, dynamic> body) => MockClient(
        (_) async => http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}),
      );

  test('무음 구간(no_speech_prob 높음)은 버리고 실제 말만 남긴다', () async {
    final stt = OpenAiSttService(
      apiKey: 'k',
      httpClient: clientReturning({
        'text': '지어낸 말 진짜 강의 내용',
        'segments': [
          {'text': '지어낸 말', 'no_speech_prob': 0.95},
          {'text': '진짜 강의 내용', 'no_speech_prob': 0.05},
        ],
      }),
    );
    expect(await stt.transcribe(audio.path), '진짜 강의 내용');
  });

  test('전부 무음이면 빈 문자열 → 이후 "너무 짧음"으로 처리된다', () async {
    final stt = OpenAiSttService(
      apiKey: 'k',
      httpClient: clientReturning({
        'text': '시청해 주셔서 감사합니다',
        'segments': [
          {'text': '시청해 주셔서 감사합니다', 'no_speech_prob': 0.9},
        ],
      }),
    );
    expect(await stt.transcribe(audio.path), isEmpty);
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/class_session.dart';
import '../ai/claude/claude_client.dart';

/// 시간표 사진에서 수업(요일·시간·강의명)을 읽어 낸다.
abstract class TimetableOcr {
  /// 네이티브: 파일 경로로 읽는다.
  Future<List<ClassSession>> extract(String imagePath);

  /// 웹: 파일 경로가 없어 바이트로 읽는다([mediaType]은 image/png 등).
  Future<List<ClassSession>> extractBytes(Uint8List bytes, String mediaType);
}

/// Claude 비전으로 시간표를 읽는 실제 구현.
/// 별도 OCR 서비스나 키가 필요 없다 — 정리에 쓰는 Claude 키를 그대로 쓴다.
class ClaudeTimetableOcr implements TimetableOcr {
  ClaudeTimetableOcr(this._client);
  final ClaudeClient _client;

  @override
  Future<List<ClassSession>> extract(String imagePath) async =>
      extractBytes(await File(imagePath).readAsBytes(), _mediaType(imagePath));

  @override
  Future<List<ClassSession>> extractBytes(
      Uint8List bytes, String mediaType) async {
    final text = await _client.completeVision(
      system: '너는 시간표 이미지를 정확히 읽어 구조화하는 도우미야.',
      maxTokens: 2048,
      mediaType: mediaType,
      imageBytes: bytes,
      userPrompt: '''
이 시간표 사진에서 모든 수업을 읽어줘. 각 수업마다 요일, 시작시간, 종료시간, 강의명을 뽑아.
시간은 24시간 형식(예: 09:00)으로 써. 못 읽는 값은 빈 문자열("")로 둬.
반드시 아래 JSON 배열 형식으로만 출력해. 코드블록이나 설명은 붙이지 마.
[
  {"day": "월", "startTime": "09:00", "endTime": "10:30", "courseName": "경제학원론"}
]''',
    );
    final list = jsonDecode(_extractJsonArray(text)) as List<dynamic>;
    return list
        .map((e) => ClassSession.fromMap(e as Map<dynamic, dynamic>))
        .where((c) => c.courseName.isNotEmpty)
        .toList();
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

/// 키 없이 흐름을 시연하기 위한 목 구현.
class MockTimetableOcr implements TimetableOcr {
  @override
  Future<List<ClassSession>> extract(String imagePath) => _sample();

  @override
  Future<List<ClassSession>> extractBytes(Uint8List bytes, String mediaType) =>
      _sample();

  Future<List<ClassSession>> _sample() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const [
      ClassSession(
          courseName: '경제학원론', day: '월', startTime: '09:00', endTime: '10:30'),
      ClassSession(
          courseName: '심리학개론', day: '화', startTime: '11:00', endTime: '12:30'),
      ClassSession(
          courseName: '컴퓨터의 이해', day: '수', startTime: '13:00', endTime: '14:30'),
    ];
  }
}

/// 모델 응답에서 JSON 배열 부분만 안전하게 추출한다(코드펜스·앞뒤 설명 제거).
String _extractJsonArray(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    t = t.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '').trim();
  }
  final start = t.indexOf('[');
  final end = t.lastIndexOf(']');
  if (start == -1 || end == -1 || end < start) {
    throw Exception('시간표를 읽지 못했어요: $text');
  }
  return t.substring(start, end + 1);
}

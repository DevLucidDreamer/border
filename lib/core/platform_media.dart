import 'dart:convert';
import 'dart:io' show File;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// 미디어(생성 음성·삽화)를 플랫폼에 상관없이 다루기 위한 얇은 어댑터.
///
/// - 네이티브: 파일 시스템에 저장하고 "파일 경로" 문자열을 로케이터로 쓴다.
/// - 웹: 파일 시스템이 없으므로 "data URL"(data:...;base64,...)을 로케이터로 쓴다.
///
/// 이 로케이터 문자열은 Unit/KeywordCard에 그대로 저장되어(로컬 저장소에도)
/// 재생·표시 시 아래 헬퍼가 형식을 판별해 알맞게 처리한다.

bool _isDataUrl(String s) => s.startsWith('data:');

/// 바이트를 data URL 문자열로 만든다(웹 미디어 저장용).
String toDataUrl(List<int> bytes, String mime) =>
    'data:$mime;base64,${base64Encode(bytes)}';

/// 로케이터가 실제로 표시/재생 가능한지. 네이티브 경로는 파일 존재까지 확인한다.
bool mediaExists(String? locator) {
  if (locator == null || locator.isEmpty) return false;
  if (_isDataUrl(locator)) return true; // 웹 data URL은 항상 유효
  return File(locator).existsSync(); // 네이티브 파일 경로만 여기 도달
}

/// 삽화 이미지 위젯. data URL이면 메모리에서, 파일 경로면 파일에서 읽는다.
Widget mediaImage(String locator, {BoxFit fit = BoxFit.contain}) {
  if (_isDataUrl(locator)) {
    final b64 = locator.substring(locator.indexOf(',') + 1);
    return Image.memory(base64Decode(b64), fit: fit);
  }
  return Image.file(File(locator), fit: fit);
}

/// 오디오 재생 소스. data URL이면 URL 소스로(웹 <audio> src),
/// 파일 경로면 기기 파일 소스로 재생한다.
Source audioSource(String locator) =>
    _isDataUrl(locator) ? UrlSource(locator) : DeviceFileSource(locator);

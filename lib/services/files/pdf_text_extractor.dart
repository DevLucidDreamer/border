import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../ai/claude/claude_client.dart';

/// PDF에서 본문 텍스트를 추출한다.
///
/// PDF 업로드는 STT를 거치지 않고 여기서 뽑은 텍스트를 곧바로 AI
/// 오케스트레이터의 입력(원문)으로 사용한다.
///
/// 우선 syncfusion으로 텍스트 레이어를 읽고, 비어 있으면(스캔·이미지 PDF)
/// Claude 문서 블록으로 페이지를 vision OCR 전사한다(키 있을 때만).
class PdfContentExtractor {
  PdfContentExtractor({this.claude});

  /// OCR 폴백용 Claude 클라이언트(없으면 텍스트 레이어만 사용).
  final ClaudeClient? claude;

  /// [path]의 PDF 전체 텍스트를 추출한다. 빈 문자열이면 추출 실패로 본다.
  Future<String> extract(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    String text;
    try {
      // 텍스트 레이어가 있는 PDF는 여기서 바로 읽힌다(빠르고 정확).
      text = PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
    // 키가 없으면 폴백 불가 — 뽑힌 그대로(비었거나 깨졌더라도) 돌려준다.
    if (claude == null) return text;
    // 텍스트 레이어가 정상이면 그대로 사용. 비었거나(스캔 PDF) 유니코드 매핑이
    // 깨진(폰트 서브셋) 경우엔 Claude 문서 OCR로 실제 페이지를 읽는다.
    if (text.isNotEmpty && !_looksGarbled(text)) return text;

    // 스캔·이미지·깨진 폰트 PDF → Claude 비전 OCR로 전사.
    // ponytail: Claude document 한도(32MB·최대 100~600쪽) 초과 시 API가 거절.
    return (await claude!.completeDocument(
      system: 'PDF의 모든 글자를 원문 그대로, 페이지 순서대로 전사해줘. '
          '설명·요약·머리말 없이 본문 텍스트만 출력해.',
      userPrompt: '이 PDF의 텍스트를 그대로 추출해줘.',
      pdfBytes: bytes,
    ))
        .trim();
  }

  /// 유니코드 매핑이 깨진 추출 텍스트(모지바케) 판별.
  /// 한글·영문·숫자 등 '읽히는 문자' 비율이 낮으면 깨진 것으로 본다.
  static bool _looksGarbled(String s) {
    final chars = s.replaceAll(RegExp(r'\s'), '');
    if (chars.length < 20) return false; // 너무 짧으면 판단 보류
    final good = RegExp(r'[가-힣a-zA-Z0-9]').allMatches(chars).length;
    return good / chars.length < 0.3;
  }
}

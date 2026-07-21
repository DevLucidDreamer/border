import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF에서 본문 텍스트를 추출한다.
///
/// PDF 업로드는 STT를 거치지 않고 여기서 뽑은 텍스트를 곧바로 AI
/// 오케스트레이터의 입력(원문)으로 사용한다.
class PdfContentExtractor {
  /// [path]의 PDF 전체 텍스트를 추출한다. 빈 문자열이면 추출 실패로 본다.
  Future<String> extract(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      // syncfusion의 PdfTextExtractor로 전체 문서 텍스트를 읽는다.
      final text = PdfTextExtractor(document).extractText();
      return text.trim();
    } finally {
      document.dispose();
    }
  }
}

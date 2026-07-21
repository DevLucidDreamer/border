import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// 원본 소스 파일(녹음·업로드 음성·PDF)을 기기 내부에 보관한다.
///
/// 기획서의 로컬 우선 원칙에 따라 외부 서버에 올리지 않고, 나중에 다시
/// 들어보거나 재처리할 수 있도록 앱 전용 디렉터리에 사본을 남긴다.
class LocalFileStore {
  /// `sources/` 하위에 강의별 파일을 모아 둔다.
  Future<Directory> _sourcesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sources');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 업로드된 파일을 앱 내부로 복사하고 보관 경로를 돌려준다.
  ///
  /// 원본 확장자를 유지해 STT/PDF 처리 단계에서 형식을 구분할 수 있게 한다.
  Future<String> importFile(String sourcePath, String lectureId) async {
    final dir = await _sourcesDir();
    final ext = _extension(sourcePath);
    final dest = '${dir.path}/src_$lectureId$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// 저장된 모든 파일(원본 소스 · 생성한 음성)을 삭제한다(데이터 초기화 시).
  Future<void> wipe() async {
    if (kIsWeb) return; // 웹은 파일 시스템을 쓰지 않는다(미디어는 data URL).
    final base = await getApplicationDocumentsDirectory();
    for (final name in ['sources', 'audio']) {
      final dir = Directory('${base.path}/$name');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  /// 저장된 소스 파일을 삭제한다(강의 삭제 시).
  Future<void> deleteFile(String? path) async {
    if (path == null || kIsWeb) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.length - 6) return '';
    return path.substring(dot);
  }
}

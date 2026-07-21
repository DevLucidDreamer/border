import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 어떤 종류의 파일을 고를지.
enum PickKind { audio, pdf }

/// 사용자가 고른 파일의 최소 정보.
///
/// 네이티브는 [path](파일 경로)를 쓴다. 웹은 파일 경로가 없어 [bytes]로 내용을
/// 직접 받는다(선택 시 withData로 로드). 둘 중 사용할 수 있는 쪽을 쓴다.
class PickedFile {
  final String? path;
  final Uint8List? bytes;
  final String name;
  const PickedFile({this.path, this.bytes, required this.name});
}

/// 음성/PDF 파일 선택 다이얼로그를 감싼다.
class FilePickerService {
  Future<PickedFile?> pick(PickKind kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: kIsWeb, // 웹은 경로가 없으므로 바이트를 로드한다.
      allowedExtensions: switch (kind) {
        PickKind.audio => ['m4a', 'mp3', 'wav', 'aac', 'ogg'],
        PickKind.pdf => ['pdf'],
      },
    );
    return _toPicked(result);
  }

  /// 시간표 등 이미지 파일 하나를 고른다.
  Future<PickedFile?> pickImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: kIsWeb);
    return _toPicked(result);
  }

  PickedFile? _toPicked(FilePickerResult? result) {
    final file = result?.files.single;
    if (file == null) return null;
    // 웹은 PlatformFile.path 게터에 접근만 해도 예외를 던진다 — bytes만 쓴다.
    if (kIsWeb) {
      if (file.bytes == null) return null;
      return PickedFile(bytes: file.bytes, name: file.name);
    }
    if (file.path == null) return null;
    return PickedFile(path: file.path, name: file.name);
  }
}

import 'package:file_picker/file_picker.dart';

/// 어떤 종류의 파일을 고를지.
enum PickKind { audio, pdf }

/// 사용자가 고른 파일의 최소 정보.
class PickedFile {
  final String path;
  final String name;
  const PickedFile({required this.path, required this.name});
}

/// 음성/PDF 파일 선택 다이얼로그를 감싼다.
class FilePickerService {
  Future<PickedFile?> pick(PickKind kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: switch (kind) {
        PickKind.audio => ['m4a', 'mp3', 'wav', 'aac', 'ogg'],
        PickKind.pdf => ['pdf'],
      },
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return null;
    return PickedFile(path: file.path!, name: file.name);
  }

  /// 시간표 등 이미지 파일 하나를 고른다.
  Future<PickedFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = result?.files.single;
    if (file == null || file.path == null) return null;
    return PickedFile(path: file.path!, name: file.name);
  }
}

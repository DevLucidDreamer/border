import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 마이크 녹음을 담당하는 얇은 래퍼.
///
/// 녹음 결과는 STT 서비스로 전달된다. 실제 녹음이 어려운 환경(권한 미허용·
/// 마이크 없음)에서도 데모가 가능하도록, 녹음을 시작하지 못하면 조용히 실패하고
/// 상위 파이프라인은 목(mock) STT로 계속 진행한다.
///
/// - 네이티브: 파일로 녹음하고 [stop]이 파일 경로를 돌려준다.
/// - 웹: 파일 시스템이 없어 blob으로 녹음되고 [stop]이 blob URL을 돌려준다.
///   그 바이트는 [webBytes]로 읽어 STT에 넘긴다.
class LectureRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// 녹음을 시작한다. 마이크 권한/장치가 없으면 false를 반환한다.
  Future<bool> start(String lectureId) async {
    try {
      if (!await _recorder.hasPermission()) return false;
      if (kIsWeb) {
        // 웹은 경로 대신 blob에 녹음한다(path는 무시되지만 인자는 필요).
        await _recorder.start(const RecordConfig(), path: 'rec_$lectureId');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/rec_$lectureId.m4a';
        await _recorder.start(const RecordConfig(), path: path);
      }
      _isRecording = true;
      return true;
    } catch (_) {
      _isRecording = false;
      return false;
    }
  }

  /// 녹음을 멈추고 로케이터(네이티브 파일 경로 / 웹 blob URL)를 반환한다.
  /// 실패 시 null.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    try {
      return await _recorder.stop();
    } catch (_) {
      return null;
    } finally {
      _isRecording = false;
    }
  }

  /// 웹 blob URL에서 녹음 바이트를 읽는다(STT 입력용). 네이티브에선 쓰지 않는다.
  Future<Uint8List?> webBytes(String blobUrl) async {
    try {
      final res = await http.get(Uri.parse(blobUrl));
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}

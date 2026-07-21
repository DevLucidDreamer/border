import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 마이크 녹음을 담당하는 얇은 래퍼.
///
/// 녹음 결과 파일 경로는 STT 서비스로 전달된다. 실제 녹음이 어려운 환경
/// (권한 미허용·마이크 없음)에서도 데모가 가능하도록, 녹음을 시작하지
/// 못하면 조용히 실패하고 상위 파이프라인은 목(mock) STT로 계속 진행한다.
class LectureRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// 녹음을 시작한다. 마이크 권한/장치가 없으면 false를 반환한다.
  Future<bool> start(String lectureId) async {
    try {
      if (!await _recorder.hasPermission()) return false;
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/rec_$lectureId.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _isRecording = true;
      return true;
    } catch (_) {
      _isRecording = false;
      return false;
    }
  }

  /// 녹음을 멈추고 저장된 파일 경로를 반환한다. 실패 시 null.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    try {
      final path = await _recorder.stop();
      return path;
    } catch (_) {
      return null;
    } finally {
      _isRecording = false;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}

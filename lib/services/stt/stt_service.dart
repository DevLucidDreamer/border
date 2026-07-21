/// 음성 → 텍스트 변환(STT) 서비스 인터페이스.
///
/// 실제 구현(다글로·클로바노트 등 외부 API)은 이 인터페이스만 구현하면
/// 되고, 파이프라인 나머지는 바뀌지 않는다. 지금은 [MockSttService]로
/// API 키 없이 전체 흐름을 검증한다.
abstract class SttService {
  /// [audioFilePath]의 음성을 텍스트로 변환한다.
  ///
  /// 경로가 null이면(녹음 실패 등) 데모용 샘플 텍스트를 반환할 수 있다.
  Future<String> transcribe(String? audioFilePath);
}

/// 실제 STT가 실패(크레딧 소진·네트워크 등)하면 [_fallback]으로 대체한다.
///
/// 키가 있어도 OpenAI 결제 잔액이 없으면 429가 나는데, 시연 도중 앱이
/// 멈추지 않도록 목 샘플로 흐름을 이어간다(키 없을 때와 같은 동작).
class FallbackSttService implements SttService {
  FallbackSttService(this._primary, this._fallback);

  final SttService _primary;
  final SttService _fallback;

  @override
  Future<String> transcribe(String? audioFilePath) async {
    try {
      return await _primary.transcribe(audioFilePath);
    } catch (e) {
      // ignore: avoid_print
      print('STT 실패 → 목 샘플로 대체: $e');
      return _fallback.transcribe(audioFilePath);
    }
  }
}

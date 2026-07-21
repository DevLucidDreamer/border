import 'stt_service.dart';

/// API 키 없이 전체 파이프라인을 검증하기 위한 목 STT.
///
/// 실제 강의 한 토막을 흉내 낸 원문 텍스트를 반환한다. 이 원문은 이후
/// AI 오케스트레이터가 쉬운 글로 재구성하며, 학습자에게 직접 노출되지 않는다.
class MockSttService implements SttService {
  @override
  Future<String> transcribe(String? audioFilePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _sampleLecture;
  }

  static const String _sampleLecture = '''
오늘은 수요와 공급의 법칙에 대해 살펴보겠습니다. 수요란 소비자가 어떤 재화나
서비스를 구매하고자 하는 욕구를 의미하며, 가격이 상승하면 수요량은 일반적으로
감소하는 경향을 보입니다. 이를 수요의 법칙이라고 합니다. 반대로 공급은 생산자가
재화를 판매하고자 하는 의사를 나타내며, 가격이 오르면 공급량이 증가합니다.
시장에서 수요와 공급이 일치하는 지점에서 균형 가격과 균형 거래량이 결정됩니다.
만약 가격이 균형보다 높으면 초과 공급이 발생하여 가격이 하락 압력을 받고,
가격이 균형보다 낮으면 초과 수요가 발생하여 가격이 상승 압력을 받습니다.
''';
}

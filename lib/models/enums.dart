/// 강의 녹음물의 처리 파이프라인 단계.
///
/// 녹음 시작 버튼 한 번으로 아래 단계가 백그라운드에서 순차 진행된다.
/// (기획서: "녹음 한 번으로 알아서 정리되는" 경험)
enum LectureStatus {
  /// 녹음 중.
  recording,

  /// 음성 → 텍스트 변환(STT) 중.
  transcribing,

  /// 쉬운 글로 정리 중.
  summarizing,

  /// 설명 음성 등 보조 자료 생성 중.
  generatingMedia,

  /// 키워드·복습 문항 등 학습 자료를 만드는 중.
  buildingContent,

  /// 학습 준비 완료.
  ready,

  /// 처리 실패.
  failed,

  /// 녹음이 너무 짧아 정리할 내용이 없음.
  tooShort;

  bool get isProcessing =>
      this == transcribing ||
      this == summarizing ||
      this == generatingMedia ||
      this == buildingContent;
}

/// 강의 자료가 어디서 들어왔는지.
///
/// 어느 소스든 이후 파이프라인(정리→오디오→복습)은 동일하게 흐른다.
/// 음성 계열은 STT를 거치고, PDF는 텍스트를 바로 추출한다.
enum SourceType {
  /// 앱에서 직접 녹음.
  recording,

  /// 사용자가 올린 음성 파일.
  audioFile,

  /// 사용자가 올린 PDF 파일.
  pdfFile;

  /// STT(음성→텍스트)가 필요한 소스인가.
  bool get needsStt => this == recording || this == audioFile;
}

import 'enums.dart';

/// 한 번의 "녹음 시작"으로 생성되는 강의 녹음물.
///
/// 원본 음성 파일 경로와 STT 텍스트를 보관하지만, 이 원문(rawTranscript)은
/// 학습자에게 직접 노출하지 않는다. (기획서: 정보 과부하 차단 — 정리된 결과만 제공)
class Lecture {
  final String id;
  final DateTime createdAt;

  /// 이 강의 자료가 들어온 경로(녹음/음성파일/PDF).
  final SourceType sourceType;

  /// 로컬에 보관된 원본 소스 파일 경로(녹음 음성, 업로드 음성/PDF).
  /// 기획서: 녹음/업로드본을 로컬에 저장하면서 재사용.
  final String? sourceFilePath;

  /// 로컬에 저장된 원본 녹음 파일 경로.
  final String? audioFilePath;

  /// STT 변환 결과 원문. 내부 처리용이며 UI에 노출하지 않는다.
  final String? rawTranscript;

  final LectureStatus status;

  /// 처리 실패 시 사유(내부 로깅/디버깅용).
  final String? errorMessage;

  const Lecture({
    required this.id,
    required this.createdAt,
    this.sourceType = SourceType.recording,
    this.sourceFilePath,
    this.audioFilePath,
    this.rawTranscript,
    this.status = LectureStatus.recording,
    this.errorMessage,
  });

  Lecture copyWith({
    String? sourceFilePath,
    String? audioFilePath,
    String? rawTranscript,
    LectureStatus? status,
    String? errorMessage,
  }) {
    return Lecture(
      id: id,
      createdAt: createdAt,
      sourceType: sourceType,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'sourceType': sourceType.name,
        'sourceFilePath': sourceFilePath,
        'audioFilePath': audioFilePath,
        'rawTranscript': rawTranscript,
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory Lecture.fromMap(Map<dynamic, dynamic> map) => Lecture(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        sourceType: SourceType.values
            .byName(map['sourceType'] as String? ?? SourceType.recording.name),
        sourceFilePath: map['sourceFilePath'] as String?,
        audioFilePath: map['audioFilePath'] as String?,
        rawTranscript: map['rawTranscript'] as String?,
        status: LectureStatus.values.byName(map['status'] as String),
        errorMessage: map['errorMessage'] as String?,
      );
}

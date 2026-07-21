import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/app_clock.dart';
import '../data/lecture_repository.dart';
import '../data/timetable_repository.dart';
import '../data/unit_repository.dart';
import '../models/enums.dart';
import '../models/lecture.dart';
import '../services/ai/ai_orchestrator.dart';
import '../services/ai/subject_classifier.dart';
import '../services/audio/audio_recorder.dart';
import '../services/files/local_file_store.dart';
import '../services/files/pdf_text_extractor.dart';
import '../services/stt/stt_service.dart';

/// 강의 자료를 받아들여(녹음/음성파일/PDF) 학습 준비까지 끝내는 컨트롤러.
///
/// 세 입력 경로 모두 원본을 로컬에 보관한 뒤 하나의 파이프라인으로 합류한다:
///   (음성) STT → 원문,  (PDF) 텍스트 추출 → 원문
///   → AI 오케스트레이션(쉬운 정리·오디오·복습 문항) → 로컬 저장.
class RecordingController extends ChangeNotifier {
  RecordingController({
    required this.recorder,
    required this.stt,
    required this.orchestrator,
    required this.lectureRepo,
    required this.unitRepo,
    required this.timetableRepo,
    required this.subjectClassifier,
    required this.fileStore,
    required this.pdfExtractor,
  });

  final LectureRecorder recorder;
  final SttService stt;
  final AiOrchestrator orchestrator;
  final LectureRepository lectureRepo;
  final UnitRepository unitRepo;
  final TimetableRepository timetableRepo;
  final SubjectClassifier subjectClassifier;
  final LocalFileStore fileStore;
  final PdfContentExtractor pdfExtractor;

  final _uuid = const Uuid();

  /// 정리할 가치가 있는 최소 원문 길이(공백 제외). 이보다 짧으면 사실상 아무
  /// 말도 담기지 않은 것으로 보고, 지어내는 대신 다시 녹음을 청한다.
  static const _minTranscriptChars = 10;

  LectureStatus _status = LectureStatus.ready;
  LectureStatus get status => _status;

  String? _currentLectureId;
  String? get currentLectureId => _currentLectureId;

  String? _error;
  String? get error => _error;

  bool get isRecording => _status == LectureStatus.recording;
  bool get isProcessing => _status.isProcessing;

  void _setStatus(LectureStatus s) {
    _status = s;
    notifyListeners();
  }

  // ---- 입력 경로 ① 녹음 ----

  /// 녹음을 시작한다. 마이크를 열지 못해도 데모를 위해 계속 진행한다.
  Future<void> startRecording() async {
    _error = null;
    final id = _uuid.v4();
    _currentLectureId = id;

    await lectureRepo.saveLecture(Lecture(
      id: id,
      createdAt: AppClock.now(),
      sourceType: SourceType.recording,
      status: LectureStatus.recording,
    ));
    _setStatus(LectureStatus.recording);

    // 실패해도 파이프라인은 목 STT 샘플로 이어진다.
    await recorder.start(id);
  }

  /// 녹음을 멈추고 정리 파이프라인을 끝까지 실행한다.
  Future<void> stopAndProcess() async {
    final id = _currentLectureId;
    if (id == null) return;

    await _guard(id, () async {
      final recordedPath = await recorder.stop();
      // 녹음본을 로컬에 보관한다.
      final savedPath = recordedPath == null
          ? null
          : await fileStore.importFile(recordedPath, id);

      var lecture = lectureRepo.getLecture(id)!.copyWith(
            sourceFilePath: savedPath,
            audioFilePath: savedPath,
            status: LectureStatus.transcribing,
          );
      await lectureRepo.saveLecture(lecture);
      _setStatus(LectureStatus.transcribing);

      final transcript = await stt.transcribe(savedPath ?? recordedPath);
      await _runPipeline(lecture, transcript);
    });
  }

  // ---- 입력 경로 ② 음성 파일 업로드 ----

  Future<void> ingestAudioFile(String pickedPath) async {
    final id = _uuid.v4();
    _currentLectureId = id;
    _error = null;

    await lectureRepo.saveLecture(Lecture(
      id: id,
      createdAt: AppClock.now(),
      sourceType: SourceType.audioFile,
      status: LectureStatus.transcribing,
    ));
    _setStatus(LectureStatus.transcribing);

    await _guard(id, () async {
      final savedPath = await fileStore.importFile(pickedPath, id);
      final lecture = lectureRepo.getLecture(id)!.copyWith(
            sourceFilePath: savedPath,
            audioFilePath: savedPath,
          );
      await lectureRepo.saveLecture(lecture);

      final transcript = await stt.transcribe(savedPath);
      await _runPipeline(lecture, transcript);
    });
  }

  // ---- 입력 경로 ③ PDF 업로드 ----

  Future<void> ingestPdfFile(String pickedPath) async {
    final id = _uuid.v4();
    _currentLectureId = id;
    _error = null;

    await lectureRepo.saveLecture(Lecture(
      id: id,
      createdAt: AppClock.now(),
      sourceType: SourceType.pdfFile,
      status: LectureStatus.transcribing,
    ));
    _setStatus(LectureStatus.transcribing);

    await _guard(id, () async {
      final savedPath = await fileStore.importFile(pickedPath, id);
      final lecture = lectureRepo.getLecture(id)!.copyWith(
            sourceFilePath: savedPath,
          );
      await lectureRepo.saveLecture(lecture);

      // PDF는 STT 없이 텍스트를 바로 추출한다.
      final text = await pdfExtractor.extract(savedPath);
      if (text.isEmpty) {
        throw Exception('PDF에서 글자를 읽지 못했어요.');
      }
      await _runPipeline(lecture, text);
    });
  }

  // ---- 공통 파이프라인 ----

  /// STT/추출로 얻은 원문을 받아 AI 정리·복습 문항까지 생성하고 저장한다.
  Future<void> _runPipeline(Lecture lecture, String rawText) async {
    final text = rawText.trim();
    // 담긴 말이 거의 없으면(무음·환청) 정리하지 않고 다시 녹음을 청한다.
    if (text.length < _minTranscriptChars) {
      await _discardTooShort(lecture);
      return;
    }

    await lectureRepo.saveLecture(lecture.copyWith(rawTranscript: text));

    final subject = await _resolveSubject(lecture, text);

    // 자료 1건 = 단원 1개(v5 스펙 9장). 개념으로 쪼개지 않는다.
    final unit = await orchestrator.run(
      unitId: lecture.id,
      sourceType: lecture.sourceType,
      createdAt: lecture.createdAt,
      rawTranscript: text,
      unitNo: unitRepo.all().length + 1,
      subjectName: subject,
      onStatus: _setStatus,
    );
    await unitRepo.save(unit);

    // 정리가 끝났으면 원본 녹음본은 폐기하고 정리 결과만 로컬에 남긴다.
    // (녹음 소스만 대상. 업로드한 음성/PDF는 재사용을 위해 보관한다.)
    if (lecture.sourceType == SourceType.recording) {
      await _discardRecording(lecture);
    } else {
      await lectureRepo.saveLecture(
          lecture.copyWith(status: LectureStatus.ready));
    }
    _setStatus(LectureStatus.ready);
  }

  /// 자료를 과목으로 분류한다.
  /// 녹음: 녹음 시각을 시간표에 맞춰 진행 중이던 수업으로. 업로드(음성·PDF):
  /// 시간대가 불분명하므로 내용을 보고 AI가 과목을 판단한다.
  Future<String> _resolveSubject(Lecture lecture, String text) async {
    if (lecture.sourceType == SourceType.recording) {
      return timetableRepo.subjectForTime(lecture.createdAt);
    }
    final subjects = timetableRepo.subjectNames();
    if (subjects.isEmpty) return '';
    return subjectClassifier.classify(text, subjects);
  }

  /// 정리를 마친 녹음: 원본 음성 파일을 지우고, 경로·원문을 비워 단원만
  /// 남긴다. (단원의 쉬운글·음성은 UnitRepository에 따로 보관된다.)
  Future<void> _discardRecording(Lecture lecture) async {
    await fileStore.deleteFile(lecture.audioFilePath);
    await lectureRepo.saveLecture(Lecture(
      id: lecture.id,
      createdAt: lecture.createdAt,
      sourceType: lecture.sourceType,
      status: LectureStatus.ready,
    ));
  }

  /// 녹음이 너무 짧을 때: 흔적(음성·강의 기록)을 남기지 않고 정리한 뒤,
  /// 화면에 "너무 짧다"고 알린다.
  Future<void> _discardTooShort(Lecture lecture) async {
    await fileStore.deleteFile(lecture.audioFilePath);
    await lectureRepo.deleteLecture(lecture.id);
    _setStatus(LectureStatus.tooShort);
  }

  /// 공통 예외 처리: 실패 시 상태를 failed로 남기고 사유를 보관한다.
  Future<void> _guard(String id, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      _error = e.toString();
      final lecture = lectureRepo.getLecture(id);
      if (lecture != null) {
        await lectureRepo.saveLecture(
          lecture.copyWith(status: LectureStatus.failed, errorMessage: '$e'),
        );
      }
      _setStatus(LectureStatus.failed);
    }
  }

  /// 다음 입력을 위해 상태를 초기화한다.
  void reset() {
    _currentLectureId = null;
    _error = null;
    _setStatus(LectureStatus.ready);
  }
}

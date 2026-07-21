import '../data/lecture_repository.dart';
import '../data/review_repository.dart';
import '../data/timetable_repository.dart';
import '../data/unit_repository.dart';
import '../services/ai/ai_orchestrator.dart';
import '../services/ai/claude/claude_ai_services.dart';
import '../services/ai/claude/claude_client.dart';
import '../services/ai/clova/clova_voice_service.dart';
import '../services/ai/mock/mock_ai_services.dart';
import '../services/ai/openai/openai_image_service.dart';
import '../services/ai/openai/openai_tts_service.dart';
import '../services/ai/pipeline_stages.dart';
import '../services/ai/subject_classifier.dart';
import '../services/audio/audio_recorder.dart';
import '../services/files/file_picker_service.dart';
import '../services/files/local_file_store.dart';
import '../services/files/pdf_text_extractor.dart';
import '../services/ocr/timetable_ocr.dart';
import '../services/review/review_engine.dart';
import '../services/stt/mock_stt_service.dart';
import '../services/stt/openai_stt_service.dart';
import '../services/stt/stt_service.dart';
import 'app_config.dart';

/// 앱 전역 의존성을 한곳에서 조립하는 서비스 로케이터.
///
/// API 키(`--dart-define`)가 있으면 실제 구현을, 없으면 Mock을 자동 선택한다.
/// 따라서 키 없이도 앱은 샘플 데이터로 끝까지 동작하고, 키를 넣으면 그대로
/// 실서비스로 전환된다.
class Services {
  Services._();

  static final Services instance = Services._();

  // 저장소 (LocalStore.init() 이후에 생성해야 한다)
  late final LectureRepository lectureRepository = LectureRepository();
  late final UnitRepository unitRepository = UnitRepository();
  late final ReviewRepository reviewRepository = ReviewRepository();
  late final TimetableRepository timetableRepository = TimetableRepository();

  // 3단계 복습 엔진(v5 스펙 10장)
  final ReviewEngine reviewEngine = const ReviewEngine();

  // 녹음 · 파일 처리
  final LectureRecorder recorder = LectureRecorder();
  final LocalFileStore fileStore = LocalFileStore();
  // 스캔·이미지 PDF는 Claude 문서 블록으로 OCR 폴백(_claude 재사용).
  late final PdfContentExtractor pdfExtractor =
      PdfContentExtractor(claude: _claude);
  final FilePickerService filePicker = FilePickerService();

  // Claude 클라이언트(키 있을 때만 생성)
  late final ClaudeClient? _claude = AppConfig.hasClaude
      ? ClaudeClient(
          apiKey: AppConfig.anthropicApiKey,
          model: AppConfig.claudeModel,
        )
      : null;

  // 시간표 OCR — Claude 키가 있으면 비전으로 실제 인식, 없으면 Mock.
  // (별도 OCR 키가 필요 없다 — 정리에 쓰는 Claude 키를 그대로 쓴다.)
  late final TimetableOcr timetableOcr =
      _claude != null ? ClaudeTimetableOcr(_claude) : MockTimetableOcr();

  // 업로드 자료의 과목 자동 분류(녹음은 시각으로, 업로드는 내용으로).
  late final SubjectClassifier subjectClassifier = _claude != null
      ? ClaudeSubjectClassifier(_claude)
      : MockSubjectClassifier();

  // STT — OpenAI 키가 있으면 Whisper 실제 호출, 없으면 Mock
  late final SttService sttService = AppConfig.hasOpenai
      ? FallbackSttService(
          OpenAiSttService(
              apiKey: AppConfig.openaiApiKey, model: AppConfig.sttModel),
          MockSttService(),
        )
      : MockSttService();

  // AI 오케스트레이터 — Claude 키가 있으면 정리·복습 문항 생성을 실제 호출.
  // 쉬운글 음성(TTS)은 OpenAI/CLOVA 키가 있을 때 실제 생성한다.
  late final AiOrchestrator orchestrator = AiOrchestrator(
    summarizer: _claude != null ? ClaudeSummarizer(_claude) : MockSummarizer(),
    contentBuilder: _claude != null
        ? ClaudeUnitContentBuilder(_claude)
        : MockUnitContentBuilder(),
    tts: _buildTts(),
    imageGenerator: AppConfig.hasOpenai
        ? OpenAiImageService(
            apiKey: AppConfig.openaiApiKey, model: AppConfig.imageModel)
        : MockImageGenerator(),
  );

  /// TTS(쉬운글 읽어주기) 구현 선택. 우선순위: OpenAI(자연스러움) > CLOVA > Mock.
  /// OpenAI 키는 Whisper(STT)와 공유하므로 별도 계정이 필요 없다.
  AudioSummarizer _buildTts() {
    if (AppConfig.hasOpenai) {
      return OpenAiTtsService(
        apiKey: AppConfig.openaiApiKey,
        model: AppConfig.ttsModel,
        voice: AppConfig.ttsVoice,
      );
    }
    if (AppConfig.hasClova) {
      return ClovaVoiceTtsService(
        clientId: AppConfig.clovaClientId,
        clientSecret: AppConfig.clovaClientSecret,
        speaker: AppConfig.clovaSpeaker,
      );
    }
    return MockAudioSummarizer();
  }

  /// 현재 실제 AI가 켜져 있는지(디버그/안내용).
  bool get usingRealAi => AppConfig.hasClaude;
  bool get usingRealStt => AppConfig.hasOpenai;
  bool get usingRealTts => AppConfig.hasOpenai || AppConfig.hasClova;
}

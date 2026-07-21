import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 실행 시점의 외부 API 설정.
///
/// 값을 얻는 우선순위: `--dart-define` > `.env` 파일 > 코드 기본값.
/// 어느 쪽에도 키가 없으면 서비스 로케이터가 자동으로 Mock 구현으로
/// 되돌아가므로, 키 없이도 앱은 (샘플 데이터로) 그대로 동작한다.
///
/// 사용법(둘 중 편한 쪽):
///   1) 프로젝트 루트 `.env` 파일에 값 채우기 (권장, `.env.example` 참고)
///   2) 실행 시: flutter run --dart-define=ANTHROPIC_API_KEY=...
class AppConfig {
  const AppConfig._();

  // --dart-define으로 들어온 값(컴파일 타임). 비어 있으면 .env를 본다.
  static const _defineAnthropicKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _defineOpenaiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _defineClaudeModel = String.fromEnvironment('CLAUDE_MODEL');
  static const _defineSttModel = String.fromEnvironment('STT_MODEL');
  static const _defineTtsModel = String.fromEnvironment('TTS_MODEL');
  static const _defineTtsVoice = String.fromEnvironment('TTS_VOICE');
  static const _defineImageModel = String.fromEnvironment('IMAGE_MODEL');
  static const _defineClovaId = String.fromEnvironment('CLOVA_CLIENT_ID');
  static const _defineClovaSecret = String.fromEnvironment('CLOVA_CLIENT_SECRET');
  static const _defineClovaSpeaker = String.fromEnvironment('CLOVA_SPEAKER');

  /// --dart-define(우선) → .env → 기본값 순으로 첫 번째 비어있지 않은 값을 고른다.
  static String _pick(String fromDefine, String envKey, {String fallback = ''}) {
    if (fromDefine.isNotEmpty) return fromDefine;
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet(envKey);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return fallback;
  }

  // ---- 키 ----

  /// Claude(정리·복습 문항·학습 전략)용 API 키.
  static String get anthropicApiKey =>
      _pick(_defineAnthropicKey, 'ANTHROPIC_API_KEY');

  /// OpenAI 키 — Whisper(STT)와 gpt-4o-mini-tts(TTS)가 함께 사용.
  static String get openaiApiKey => _pick(_defineOpenaiKey, 'OPENAI_API_KEY');

  /// CLOVA Voice(폴백 TTS)용 네이버 클라우드 인증.
  static String get clovaClientId => _pick(_defineClovaId, 'CLOVA_CLIENT_ID');
  static String get clovaClientSecret =>
      _pick(_defineClovaSecret, 'CLOVA_CLIENT_SECRET');

  // ---- 모델(선택 설정, 기본값 내장) ----

  static String get claudeModel =>
      _pick(_defineClaudeModel, 'CLAUDE_MODEL', fallback: 'claude-sonnet-5');
  static String get sttModel =>
      _pick(_defineSttModel, 'STT_MODEL', fallback: 'whisper-1');
  static String get ttsModel =>
      _pick(_defineTtsModel, 'TTS_MODEL', fallback: 'gpt-4o-mini-tts');
  static String get ttsVoice =>
      _pick(_defineTtsVoice, 'TTS_VOICE', fallback: 'coral');
  static String get imageModel =>
      _pick(_defineImageModel, 'IMAGE_MODEL', fallback: 'gpt-image-1');
  static String get clovaSpeaker =>
      _pick(_defineClovaSpeaker, 'CLOVA_SPEAKER', fallback: 'nara');

  // ---- 활성화 여부 ----

  static bool get hasClaude => anthropicApiKey.isNotEmpty;
  static bool get hasOpenai => openaiApiKey.isNotEmpty;
  static bool get hasClova =>
      clovaClientId.isNotEmpty && clovaClientSecret.isNotEmpty;
}

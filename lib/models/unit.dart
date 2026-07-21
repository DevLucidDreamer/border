import 'enums.dart';
import 'keyword_card.dart';
import 'quiz.dart';

/// 학습·복습의 단위 "단원"(스펙의 EasyText).
///
/// 스펙 9장 원칙: 녹음 1건 = 단원 1개, PDF 1건 = 단원 1개. AI가 내용을 더
/// 쪼개거나 합치지 않는다. 한 단원은 쉬운글(content) + 키워드 카드 + 3단계
/// 복습 문항을 함께 지닌다. 최초 학습을 마쳤는지는 [learned]로 기록한다
/// (스펙의 LearningHistory.completed).
class Unit {
  /// 단원 id(= 이 단원을 만든 Lecture id).
  final String id;
  final SourceType sourceType;
  final DateTime createdAt;

  /// 단원 번호(스펙 EasyText.unit_no). 화면 제목 "N단원"에 쓴다.
  final int unitNo;

  /// 과목명(시간표 연결 전이면 빈 문자열).
  final String subjectName;

  /// 쉬운글(스토리텔링 재구성 본문).
  final String content;

  /// 쉬운글을 읽어 주는 음성 파일 경로.
  final String? audioPath;

  final List<KeywordCard> keywordCards;

  /// 2·3단계 복습 문항 풀(재노출 시 변형 출제용).
  final List<Quiz> quizzes;

  /// 최초 학습 완료 여부와 완료일.
  final bool learned;
  final DateTime? learnedDate;

  const Unit({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    this.unitNo = 1,
    this.subjectName = '',
    required this.content,
    this.audioPath,
    this.keywordCards = const [],
    this.quizzes = const [],
    this.learned = false,
    this.learnedDate,
  });

  /// 특정 단계의 복습 문항들(없으면 빈 리스트).
  List<Quiz> quizzesForStage(int stage) =>
      quizzes.where((q) => q.stage == stage).toList();

  Unit copyWith({bool? learned, DateTime? learnedDate}) => Unit(
        id: id,
        sourceType: sourceType,
        createdAt: createdAt,
        unitNo: unitNo,
        subjectName: subjectName,
        content: content,
        audioPath: audioPath,
        keywordCards: keywordCards,
        quizzes: quizzes,
        learned: learned ?? this.learned,
        learnedDate: learnedDate ?? this.learnedDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sourceType': sourceType.name,
        'createdAt': createdAt.toIso8601String(),
        'unitNo': unitNo,
        'subjectName': subjectName,
        'content': content,
        'audioPath': audioPath,
        'keywordCards': keywordCards.map((c) => c.toMap()).toList(),
        'quizzes': quizzes.map((q) => q.toMap()).toList(),
        'learned': learned,
        'learnedDate': learnedDate?.toIso8601String(),
      };

  factory Unit.fromMap(Map<dynamic, dynamic> m) => Unit(
        id: m['id'] as String,
        sourceType: SourceType.values
            .byName(m['sourceType'] as String? ?? SourceType.recording.name),
        createdAt: DateTime.parse(m['createdAt'] as String),
        unitNo: m['unitNo'] as int? ?? 1,
        subjectName: m['subjectName'] as String? ?? '',
        content: m['content'] as String? ?? '',
        audioPath: m['audioPath'] as String?,
        keywordCards: (m['keywordCards'] as List<dynamic>? ?? [])
            .map((e) => KeywordCard.fromMap(e as Map<dynamic, dynamic>))
            .toList(),
        quizzes: (m['quizzes'] as List<dynamic>? ?? [])
            .map((e) => Quiz.fromMap(e as Map<dynamic, dynamic>))
            .toList(),
        learned: m['learned'] as bool? ?? false,
        learnedDate: m['learnedDate'] == null
            ? null
            : DateTime.parse(m['learnedDate'] as String),
      );
}

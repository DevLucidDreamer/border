/// 단원의 핵심 키워드 한 장(스펙의 ImageCard).
///
/// 1단계 복습에서 "키워드 + 그 뜻"을 함께 제시하는 데 쓰인다.
/// 그림은 아직 없으면 null(화면은 플레이스홀더).
class KeywordCard {
  final String keyword;
  final String meaning;
  final String? imagePath;

  const KeywordCard({
    required this.keyword,
    required this.meaning,
    this.imagePath,
  });

  KeywordCard copyWith({String? imagePath}) => KeywordCard(
        keyword: keyword,
        meaning: meaning,
        imagePath: imagePath ?? this.imagePath,
      );

  Map<String, dynamic> toMap() =>
      {'keyword': keyword, 'meaning': meaning, 'imagePath': imagePath};

  factory KeywordCard.fromMap(Map<dynamic, dynamic> m) => KeywordCard(
        keyword: m['keyword'] as String? ?? '',
        meaning: m['meaning'] as String? ?? '',
        imagePath: m['imagePath'] as String?,
      );
}

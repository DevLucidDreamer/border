/// 시간표에서 읽어 낸 한 수업.
///
/// 시간표 사진을 OCR로 읽어 요일·시간·강의명을 뽑은 결과다. 이후 녹음을
/// 해당 수업과 연결하는 데 쓸 수 있다.
class ClassSession {
  /// 강의명.
  final String courseName;

  /// 요일(예: 월). 못 읽었으면 빈 문자열.
  final String day;

  /// 시작 시각(예: 09:00).
  final String startTime;

  /// 종료 시각(예: 10:30). 못 읽었으면 빈 문자열.
  final String endTime;

  const ClassSession({
    required this.courseName,
    this.day = '',
    this.startTime = '',
    this.endTime = '',
  });

  ClassSession copyWith({
    String? courseName,
    String? day,
    String? startTime,
    String? endTime,
  }) =>
      ClassSession(
        courseName: courseName ?? this.courseName,
        day: day ?? this.day,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );

  Map<String, dynamic> toMap() => {
        'courseName': courseName,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory ClassSession.fromMap(Map<dynamic, dynamic> map) => ClassSession(
        courseName: map['courseName'] as String? ?? '',
        day: map['day'] as String? ?? '',
        startTime: map['startTime'] as String? ?? '',
        endTime: map['endTime'] as String? ?? '',
      );
}

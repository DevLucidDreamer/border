import 'package:hive_flutter/hive_flutter.dart';

/// 로컬 저장소 초기화 및 Hive 박스 접근 지점.
///
/// 기획서의 "전면 로컬 저장 / 백엔드 서버 없음" 원칙에 따라 모든 학습
/// 데이터는 기기 내부에만 저장된다. 모델은 build_runner 의존을 피하기 위해
/// TypeAdapter 대신 `Map` 직렬화 형태로 박스에 보관한다.
class LocalStore {
  LocalStore._();

  static const String lecturesBox = 'lectures';
  static const String unitsBox = 'units';
  static const String reviewsBox = 'reviews';
  static const String timetableBox = 'timetable';

  static bool _initialized = false;

  /// 앱 시작 시 한 번 호출. Hive를 초기화하고 필요한 박스를 연다.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(lecturesBox),
      Hive.openBox<Map>(unitsBox),
      Hive.openBox<Map>(reviewsBox),
      Hive.openBox<Map>(timetableBox),
    ]);
    _initialized = true;
  }

  static Box<Map> box(String name) => Hive.box<Map>(name);

  /// 모든 학습 데이터를 비운다(초기화). 파일 삭제는 별도로 처리한다.
  static Future<void> clearAll() async {
    await Future.wait([
      box(lecturesBox).clear(),
      box(unitsBox).clear(),
      box(reviewsBox).clear(),
      box(timetableBox).clear(),
    ]);
  }
}

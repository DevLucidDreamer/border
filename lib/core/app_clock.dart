import '../data/local_store.dart';

/// 앱 전체가 "오늘"로 삼는 시각. 평소엔 실제 시각이지만, 데모 모드에서
/// 오프셋을 주면 날짜를 앞당겨 복습 주기·시간표 과목분류를 즉석에서 시연할 수 있다.
///
/// 모든 `DateTime.now()`는 이 [now]를 거친다(복습 엔진·컨트롤러). 오프셋은
/// 로컬에 저장돼 핫리스타트에도 유지된다.
class AppClock {
  AppClock._();

  static const _key = 'demoOffsetMinutes';
  static Duration _offset = Duration.zero;

  /// 앱 시작 시 한 번 호출(LocalStore.init 이후). 저장된 오프셋을 복원한다.
  static void load() {
    final m = LocalStore.settings().get(_key);
    _offset = Duration(minutes: m is int ? m : 0);
  }

  /// 데모 오프셋이 반영된 현재 시각.
  static DateTime now() => DateTime.now().add(_offset);

  static Duration get offset => _offset;
  static bool get isShifted => _offset.inMinutes != 0;

  static set offset(Duration d) {
    _offset = d;
    LocalStore.settings().put(_key, d.inMinutes);
  }

  /// 데모 날짜를 [d]만큼 앞으로 민다(+1일 등).
  static void advance(Duration d) => offset = _offset + d;

  /// [target] 시각이 "지금"이 되도록 오프셋을 맞춘다(다음 복습일로 점프).
  static void jumpTo(DateTime target) =>
      offset = target.difference(DateTime.now()) + const Duration(minutes: 1);

  /// 실제 시각으로 되돌린다.
  static void reset() => offset = Duration.zero;
}

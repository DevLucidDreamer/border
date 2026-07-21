import '../models/review_schedule.dart';
import 'local_store.dart';

/// 복습 스케줄(ReviewSchedule)의 로컬 영속화. 단원당 스케줄 하나(unitId 키).
class ReviewRepository {
  ReviewRepository();

  final _box = LocalStore.box(LocalStore.reviewsBox);

  Future<void> save(ReviewSchedule s) => _box.put(s.unitId, s.toMap());

  ReviewSchedule? forUnit(String unitId) {
    final m = _box.get(unitId);
    return m == null ? null : ReviewSchedule.fromMap(m);
  }

  List<ReviewSchedule> all() =>
      _box.values.map(ReviewSchedule.fromMap).toList();

  Future<void> delete(String unitId) => _box.delete(unitId);
}

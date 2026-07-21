import '../models/unit.dart';
import 'local_store.dart';

/// 단원(EasyText)의 로컬 영속화를 담당한다.
class UnitRepository {
  UnitRepository();

  final _box = LocalStore.box(LocalStore.unitsBox);

  Future<void> save(Unit unit) => _box.put(unit.id, unit.toMap());

  Unit? get(String id) {
    final m = _box.get(id);
    return m == null ? null : Unit.fromMap(m);
  }

  List<Unit> all() => _box.values.map(Unit.fromMap).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> delete(String id) => _box.delete(id);
}

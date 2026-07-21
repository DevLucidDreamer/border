import '../models/lecture.dart';
import 'local_store.dart';

/// 강의 녹음물/업로드 자료(Recording·PDF)의 로컬 영속화를 담당한다.
/// 자료에서 만들어진 학습 단원은 [UnitRepository]가 따로 보관한다.
class LectureRepository {
  LectureRepository();

  final _lectures = LocalStore.box(LocalStore.lecturesBox);

  Future<void> saveLecture(Lecture lecture) =>
      _lectures.put(lecture.id, lecture.toMap());

  Lecture? getLecture(String id) {
    final map = _lectures.get(id);
    return map == null ? null : Lecture.fromMap(map);
  }

  List<Lecture> allLectures() => _lectures.values
      .map(Lecture.fromMap)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> deleteLecture(String id) => _lectures.delete(id);
}

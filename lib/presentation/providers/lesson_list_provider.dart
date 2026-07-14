import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/lesson_repository.dart';
import '../../domain/models/lesson_plan.dart';
import 'core_providers.dart';

class LessonListController extends StateNotifier<List<LessonPlan>> {
  final LessonRepository _repo;

  LessonListController(this._repo) : super(_repo.getAllLessons());

  void refresh() => state = _repo.getAllLessons();

  Future<void> delete(String id) async {
    await _repo.delete(id);
    refresh();
  }
}

final lessonListControllerProvider =
    StateNotifierProvider<LessonListController, List<LessonPlan>>((ref) {
  return LessonListController(ref.watch(lessonRepositoryProvider));
});

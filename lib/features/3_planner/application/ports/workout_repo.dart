// lib/features/3_planner/application/ports/workout_repo.dart
import 'package:fitapp/core/models/models.dart';
import '../../../3_planner/domain/value_objects/slug.dart';

abstract class WorkoutRepo {
  Future<String> upsertExercise(Exercise dto, {String? slug});
  Future<String> upsertSession(WorkoutSession dto, {String? slug});
  Future<String> upsertDay(WorkoutDay dto, {String? slug});
  Future<String> upsertRoutine(WorkoutRoutine dto, {String? slug});
  Future<void> saveSchedule(String routineId, List<String> slotKinds, List<String?> dayIds);
  Exercise? findExerciseBySlug(String slug);
  WorkoutSession? findSessionBySlug(String slug);
  WorkoutDay? findDayBySlug(String slug);
  WorkoutRoutine? findRoutineBySlug(String slug);
}

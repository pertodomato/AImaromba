// lib/data/repositories/workout_repository.dart

// Stubs de modelos para compilar. Serão substituídos por modelos reais.
typedef ProfileId = int;
typedef WorkoutId = int;
typedef ExerciseId = String;
class Workout {}
class SetInput {}
class WorkoutSummary {}


abstract interface class WorkoutRepository {
  Future<Workout> startWorkout(ProfileId id);
  Future<void> addSet(WorkoutId w, ExerciseId e, SetInput input);
  Future<void> finishWorkout(WorkoutId w);
  Stream<WorkoutSummary> todaySummary(ProfileId id);
  Stream<bool> hasActiveWorkout(ProfileId id);
}
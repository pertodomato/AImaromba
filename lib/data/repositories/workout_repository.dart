// lib/data/repositories/workout_repository.dart
typedef ProfileId = int;
typedef WorkoutId = int;
typedef ExerciseId = String;

class WorkoutHistoryEntry {
  final DateTime date;
  final String muscleGroup;
  final String exerciseName;
  final double weight;
  final int reps;
  WorkoutHistoryEntry({
    required this.date,
    required this.muscleGroup,
    required this.exerciseName,
    required this.weight,
    required this.reps,
  });
}

abstract interface class WorkoutRepository {
  Future<void> addSet(WorkoutId w, ExerciseId e, int reps, double weight);
  Future<void> finishWorkout(WorkoutId w);
  Stream<bool> hasActiveWorkout(ProfileId id);

  // adicionados
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory(ProfileId id);
  Stream<Map<String, double>> getMuscleGroupRecency(ProfileId id);
}

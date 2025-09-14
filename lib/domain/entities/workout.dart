// lib/domain/entities/workout.dart
class ActiveWorkout {
  final int workoutId;
  final DateTime date;
  final List<WorkoutSet> sets;
  ActiveWorkout({required this.workoutId, required this.date, this.sets = const []});
}

class WorkoutSet {
  final String exerciseId;
  final int reps;
  final double weight;
  WorkoutSet({required this.exerciseId, required this.reps, required this.weight});
}
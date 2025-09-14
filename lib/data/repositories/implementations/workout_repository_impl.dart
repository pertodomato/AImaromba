// lib/data/repositories/implementations/workout_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/domain/entities/workout.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final AppDatabase _db;
  WorkoutRepositoryImpl(this._db);

  @override
  Stream<bool> hasActiveWorkout(int profileId) {
    final query = _db.select(_db.workouts)
      ..where((tbl) => tbl.profileId.equals(profileId))
      ..where((tbl) => tbl.status.equals('active'));
    return query.watch().map((workouts) => workouts.isNotEmpty);
  }

  @override
  Future<ActiveWorkout?> getActiveWorkout(int profileId) async {
    final query = _db.select(_db.workouts)
      ..where((tbl) => tbl.profileId.equals(profileId))
      ..where((tbl) => tbl.status.equals('active'));
    
    final workoutData = await query.getSingleOrNull();
    if (workoutData == null) return null;

    final setsData = await (_db.select(_db.workoutSets)..where((s) => s.workoutId.equals(workoutData.id))).get();

    return ActiveWorkout(
      workoutId: workoutData.id,
      date: workoutData.date,
      sets: setsData.map((s) => WorkoutSet(
        exerciseId: s.exerciseId,
        reps: s.reps,
        weight: s.weight,
      )).toList(),
    );
  }
  
  // Implementações adicionais...
  @override
  Future<void> addSet(int workoutId, String exerciseId, int reps, double weight) async {
    await _db.into(_db.workoutSets).insert(WorkoutSetsCompanion.insert(
      workoutId: workoutId,
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> finishWorkout(int workoutId) async {
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      const WorkoutsCompanion(status: Value('finished')),
    );
  }

  @override
  Stream<Map<String, double>> getMuscleGroupRecency(int profileId) {
    // Retorna um mapa de 'muscle_group' para dias desde o último treino
    final query = _db.select(_db.workoutSets).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.workoutSets.exerciseId)),
    ])
    ..addColumns([_db.exercises.muscleGroup, _db.workoutSets.timestamp.max()]);
    
    query.groupBy([_db.exercises.muscleGroup]);

    return query.watch().map((rows) {
      final Map<String, double> recencyMap = {};
      final now = DateTime.now();
      for (final row in rows) {
        final group = row.read(_db.exercises.muscleGroup)!;
        final lastDate = row.read(_db.workoutSets.timestamp.max())!;
        final days = now.difference(lastDate).inDays.toDouble();
        recencyMap[group] = days;
      }
      return recencyMap;
    });
  }

  // Outros métodos da interface...
}
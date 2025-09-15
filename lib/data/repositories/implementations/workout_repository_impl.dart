import 'package:drift/drift.dart' as drift;
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

    final setsData = await (_db.select(_db.workoutSets)
          ..where((s) => s.workoutId.equals(workoutData.id)))
        .get();

    return ActiveWorkout(
      workoutId: workoutData.id,
      date: workoutData.date,
      sets: setsData
          .map((s) => WorkoutSet(
                exerciseId: s.exerciseId,
                reps: s.reps,
                weight: s.weight,
              ))
          .toList(),
    );
  }

  @override
  Future<void> addSet(int workoutId, String exerciseId, int reps, double weight) async {
    await _db.into(_db.workoutSets).insert(
      WorkoutSetsCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        reps: reps,
        weight: weight,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> finishWorkout(int workoutId) async {
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(status: drift.Value('finished')),
    );
  }

  @override
  Stream<Map<String, double>> getMuscleGroupRecency(int profileId) {
    final j = _db.select(_db.workoutSets).join([
      drift.innerJoin(_db.workouts, _db.workouts.id.equalsExp(_db.workoutSets.workoutId)),
      drift.innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.workoutSets.exerciseId)),
    ])
      ..where(_db.workouts.profileId.equals(profileId))
      ..addColumns([_db.exercises.muscleGroup, _db.workoutSets.timestamp.max()])
      ..groupBy([_db.exercises.muscleGroup]);

    return j.watch().map((rows) {
      final now = DateTime.now();
      final out = <String, double>{};
      for (final r in rows) {
        final group = r.read(_db.exercises.muscleGroup) ?? 'unknown';
        final last = r.read(_db.workoutSets.timestamp.max());
        if (last == null) continue;
        out[group] = now.difference(last).inDays.toDouble();
      }
      return out;
    });
  }

  @override
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory(int profileId) async {
    final workouts = await (_db.select(_db.workouts)
          ..where((w) => w.profileId.equals(profileId)))
        .get();
    if (workouts.isEmpty) return [];

    final ids = workouts.map((w) => w.id).toList();

    final sets = await (_db.select(_db.workoutSets)
          ..where((s) => s.workoutId.isIn(ids)))
        .get();

    final exs = await _db.select(_db.exercises).get();
    final exById = {for (final e in exs) e.id: e};
    final wkById = {for (final w in workouts) w.id: w};

    final out = <WorkoutHistoryEntry>[];
    for (final s in sets) {
      final w = wkById[s.workoutId];
      if (w == null) continue;
      final ex = exById[s.exerciseId];
      out.add(WorkoutHistoryEntry(
        date: w.date,
        muscleGroup: ex?.muscleGroup ?? 'unknown',
        exerciseName: ex?.name ?? s.exerciseId,
        weight: s.weight,
        reps: s.reps,
      ));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }
}

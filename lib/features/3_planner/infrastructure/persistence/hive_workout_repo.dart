// lib/features/3_planner/infrastructure/persistence/hive_workout_repo.dart
import 'package:hive/hive.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';
import 'package:fitapp/core/utils/muscle_validation.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

class HiveWorkoutRepo {
  final Box<Exercise> exBox;
  final Box<WorkoutSession> sessBox;
  final Box<WorkoutDay> dayBox;
  final Box<WorkoutRoutine> routineBox;
  final Box<WorkoutBlock> blockBox;
  final Box<WorkoutRoutineSchedule> routineScheduleBox;

  HiveWorkoutRepo({
    required this.exBox,
    required this.sessBox,
    required this.dayBox,
    required this.routineBox,
    required this.blockBox,
    required this.routineScheduleBox,
  });

  // ---------- Exercises ----------
  Exercise upsertExercise({
    required String name,
    required String description,
    required List<String> primary,
    required List<String> secondary,
    required List<String> metrics,
  }) {
    final prim = primary.where(isValidGroupId).toList();
    final sec = secondary.where(isValidGroupId).toList();

    final s = toSlug(name);
    for (final e in exBox.values) {
      if (toSlug(e.name) == s) return e;
    }

    final ex = Exercise(
      id: s,
      name: name,
      description: description,
      primaryMuscles: prim,
      secondaryMuscles: sec,
      relevantMetrics: metrics,
    );

    exBox.put(ex.id, ex);
    // ignore: avoid_print
    print('.. saved EXERCISE: ${ex.id} | $name');
    return ex;
  }

  // ---------- Sessions ----------
  WorkoutSession upsertSession({
    required String name,
    required String description,
    required List<Exercise> exercises,
  }) {
    final s = toSlug(name);
    for (final sess in sessBox.values) {
      if (toSlug(sess.name) == s) return sess;
    }

    final sess = WorkoutSession(
      id: s,
      name: name,
      description: description,
      exercises: HiveList<Exercise>(exBox, objects: exercises),
    );

    sessBox.put(sess.id, sess);
    // ignore: avoid_print
    print('.. saved SESSION: ${sess.id} | $name (ex: ${exercises.length})');
    return sess;
  }

  // ---------- Days ----------
  WorkoutDay upsertDay({
    required String name,
    required String description,
    required List<WorkoutSession> sessions,
  }) {
    final s = toSlug(name);
    for (final d in dayBox.values) {
      if (toSlug(d.name) == s) return d;
    }

    final day = WorkoutDay(
      id: s,
      name: name,
      description: description,
      sessions: HiveList<WorkoutSession>(sessBox, objects: sessions),
    );

    dayBox.put(day.id, day);
    // ignore: avoid_print
    print('.. saved DAY: ${day.id} | $name (sessions: ${sessions.length})');
    return day;
  }

  // ---------- Blocks ----------
  WorkoutBlock upsertBlock({
    required String name,
    required String description,
    required List<WorkoutDay> daysOrdered,
  }) {
    final s = toSlug(name);
    for (final b in blockBox.values) {
      if (b.slug == s) return b;
    }

    final block = WorkoutBlock(
      slug: s,
      name: name,
      description: description,
      daySlugs: daysOrdered.map((d) => toSlug(d.name)).toList(),
    );

    blockBox.put(block.slug, block);
    // ignore: avoid_print
    print('.. saved BLOCK: ${block.slug} | $name (days: ${daysOrdered.length})');
    return block;
  }

  // ---------- Routine & Schedule ----------
  WorkoutRoutine upsertRoutine({
    required String name,
    required String description,
    required String repetitionSchema,
  }) {
    final s = toSlug(name);
    for (final r in routineBox.values) {
      if (toSlug(r.name) == s) return r;
    }

    final r = WorkoutRoutine(
      id: s,
      name: name,
      description: description,
      startDate: DateTime.now(),
      repetitionSchema: repetitionSchema,
      days: HiveList<WorkoutDay>(dayBox, objects: const []),
    );

    routineBox.put(r.id, r);
    // ignore: avoid_print
    print('.. saved ROUTINE: ${r.id} | $name');
    return r;
  }

  WorkoutRoutineSchedule upsertRoutineSchedule({
    required String routineSlug,
    required String repetitionSchema,
    required List<WorkoutBlock> sequence,
  }) {
    final canonical = toSlug(routineSlug);
    final existing =
        routineScheduleBox.values.where((sch) => sch.routineSlug == canonical).toList();

    if (existing.isNotEmpty) {
      final sch = existing.first;
      sch.blockSequence = sequence.map((b) => b.slug).toList();
      sch.repetitionSchema = repetitionSchema;
      sch.save();
      // ignore: avoid_print
      print('.. updated WORKOUT SCHEDULE: $canonical -> ${sch.blockSequence}');
      return sch;
    }

    final sch = WorkoutRoutineSchedule(
      routineSlug: canonical,
      blockSequence: sequence.map((b) => b.slug).toList(),
      repetitionSchema: repetitionSchema,
    );

    routineScheduleBox.put(canonical, sch);
    // ignore: avoid_print
    print('.. saved WORKOUT SCHEDULE: $canonical -> ${sch.blockSequence}');
    return sch;
  }
}

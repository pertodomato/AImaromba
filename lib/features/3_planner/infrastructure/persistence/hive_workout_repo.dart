// lib/features/3_planner/infrastructure/persistence/hive_workout_repo.dart
import 'package:hive/hive.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';
import 'package:fitapp/core/utils/muscle_validation.dart';

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

  // ---------- Utils ----------
  String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  // ---------- Exercises ----------
  Exercise upsertExercise({
    required String name,
    required String description,
    required List<String> primary,
    required List<String> secondary,
    required List<String> metrics,
  }) {
    // valida músculos
    final prim = primary.where(isValidGroupId).toList();
    final sec = secondary.where(isValidGroupId).toList();

    // procura por nome
    final slug = _slug(name);
    for (final e in exBox.values) {
      if (_slug(e.name) == slug) return e;
    }
    final ex = Exercise()
      ..name = name
      ..description = description
      ..primaryMuscles = prim
      ..secondaryMuscles = sec
      ..relevantMetrics = metrics;
    exBox.add(ex);
    return ex;
  }

  // ---------- Sessions ----------
  WorkoutSession upsertSession({
    required String name,
    required String description,
    required List<Exercise> exercises,
  }) {
    final slug = _slug(name);
    for (final s in sessBox.values) {
      if (_slug(s.name) == slug) return s;
    }
    final sess = WorkoutSession()
      ..name = name
      ..description = description
      ..exerciseIds = exercises.map((e) => e.key as int).toList();
    sessBox.add(sess);
    return sess;
  }

  // ---------- Days ----------
  WorkoutDay upsertDay({
    required String name,
    required String description,
    required bool isRest,
    required List<WorkoutSession> sessions,
  }) {
    final slug = _slug(name);
    for (final d in dayBox.values) {
      if (_slug(d.name) == slug) return d;
    }
    final day = WorkoutDay()
      ..name = name
      ..description = description
      ..isRest = isRest
      ..sessionIds = sessions.map((s) => s.key as int).toList();
    dayBox.add(day);
    return day;
  }

  // ---------- Blocks ----------
  WorkoutBlock upsertBlock({
    required String name,
    required String description,
    required List<WorkoutDay> daysOrdered, // 1–15
  }) {
    final slug = _slug(name);
    for (final b in blockBox.values) {
      if (_slug(b.name) == slug) return b;
    }
    final block = WorkoutBlock(
      slug: slug,
      name: name,
      description: description,
      daySlugs: daysOrdered.map((d) => _slug(d.name)).toList(),
    );
    blockBox.add(block);
    return block;
  }

  // ---------- Routine & Schedule ----------
  WorkoutRoutine upsertRoutine({
    required String name,
    required String description,
  }) {
    final slug = _slug(name);
    for (final r in routineBox.values) {
      if (_slug(r.name) == slug) return r;
    }
    final r = WorkoutRoutine()
      ..name = name
      ..description = description;
    routineBox.add(r);
    return r;
  }

  WorkoutRoutineSchedule upsertRoutineSchedule({
    required String routineSlug,
    required String repetitionSchema,
    required List<WorkoutBlock> sequence,
  }) {
    // 1 rotina → 1 schedule
    for (final s in routineScheduleBox.values) {
      if (s.routineSlug == routineSlug) {
        s.blockSequence = sequence.map((b) => b.slug).toList();
        s.repetitionSchema = repetitionSchema;
        s.save();
        return s;
      }
    }
    final sch = WorkoutRoutineSchedule(
      routineSlug: routineSlug,
      blockSequence: sequence.map((b) => b.slug).toList(),
      repetitionSchema: repetitionSchema,
    );
    routineScheduleBox.add(sch);
    return sch;
  }
}

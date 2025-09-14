import 'dart:convert';
import 'package:drift/drift.dart';
import '../core/db/app_db.dart';
import '../utils/shared.dart';

class WorkoutRepository {
  final AppDatabase db;
  WorkoutRepository(this.db);

  Future<Map<String, dynamic>?> todaysPlannedBlock() async {
    final today = DateTime.now().toIso8601String().substring(0,10);
    final plan = await db.select(db.plannedWorkouts).where((t)=> t.date.equals(today)).getSingleOrNull();
    if (plan == null) return null;
    if (plan.blockId == null || plan.blockId == 'descanso') return null;
    final block = await db.select(db.blocks).where((b)=> b.id.equals(plan.blockId!)).getSingleOrNull();
    if (block == null) return null;
    final items = await (db.select(db.blockExercises)..where((be)=> be.blockId.equals(block.id))).get();

    return {
      'id': block.id,
      'name': block.name,
      'estimatedDurationMin': block.estimatedDurationMin,
      'exercises': items.map((it)=> {
        'exerciseId': it.exerciseId,
        'sets': it.sets,
        'reps': it.reps,
        'restSec': it.restSec,
        'timeSec': it.timeSec,
        'distanceKm': it.distanceKm,
        'speedKmh': it.speedKmh,
        'gradientPercent': it.gradientPercent,
        'progression': jsonDecode(it.progressionJson),
      }).toList(),
    };
  }

  Future<int?> inProgressSessionId() async {
    final s = await (db.select(db.sessions)
          ..where((t)=> t.inProgress.equals(true))
          ..orderBy([(t)=> OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    return s?.id;
  }

  Future<int> startSession(String blockId, String name) async {
    final sId = await db.into(db.sessions).insert(SessionsCompanion.insert(
      date: DateTime.now().toIso8601String().substring(0,10),
      blockId: Value(blockId),
      name: name,
      inProgress: const Value(true),
      startedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    return sId;
  }

  Future<void> saveSet({
    required int sessionId,
    required String exerciseId,
    required int setIndex,
    double? weight,
    int? reps,
    double? distanceKm,
    double? timeMin,
  }) async {
    await db.into(db.sessionSets).insert(SessionSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      weight: Value(weight),
      reps: Value(reps),
      distanceKm: Value(distanceKm),
      timeMin: Value(timeMin),
    ));
  }

  Future<void> finishSession({
    required int sessionId,
    required double bodyWeightKg,
  }) async {
    // cálculo de kcal via MET médio ponderado por tempo estimado
    final sets = await (db.select(db.sessionSets)..where((t)=> t.sessionId.equals(sessionId))).get();
    // fallback simples: 40s por série + 60s descanso para força, tempoMin para cardio
    double totalMinutes = 0;
    for (final s in sets) {
      totalMinutes += (s.timeMin ?? ((40.0 + 60.0) / 60.0));
    }
    // heurística: MET médio 6.0
    final kcal = kcalFromMET(met: 6.0, bodyWeightKg: bodyWeightKg, minutes: totalMinutes);

    await (db.update(db.sessions)..where((t)=> t.id.equals(sessionId))).write(
      SessionsCompanion(
        calories: Value(kcal),
        inProgress: const Value(false),
        endedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // ----- Dados para Muscle Screen -----
  /// Mapa grupo_muscular -> última data (YYYY-MM-DD)
  Future<Map<String,String>> lastTrainDateByMuscle() async {
    // aproximação: associa exercício->primaryGroupsJson
    final all = await db.select(db.exercises).get();
    final byExercise = {
      for (final e in all) e.id: (List<String>.from((jsonDecode(e.primaryGroupsJson) as List)))
    };

    final sessions = await (db.select(db.sessions)
          ..orderBy([(t)=> OrderingTerm.desc(t.date)]))
        .get();

    final sets = await db.select(db.sessionSets).get();
    final bySession = <int,List<SessionSet>>{};
    for (final s in sets) {
      (bySession[s.sessionId] ??= []).add(s);
    }

    final Map<String,String> last = {};
    for (final s in sessions) {
      final ss = bySession[s.id] ?? const <SessionSet>[];
      for (final set in ss) {
        final groups = byExercise[set.exerciseId] ?? const <String>[];
        for (final g in groups) {
          last[g] ??= s.date;
        }
      }
    }
    return last;
  }

  /// Percentis de força: usa bests do profile e util.percentileFor
  Future<Map<String,double>> percentiles({
    required String genderKey,
    required double bodyWeight,
  }) async {
    // Apenas para chaves padrão
    final out = <String,double>{};
    // Chame util.percentileFor(exerciseKey: 'supino'|..., genderKey, bodyWeight, value)
    // Repo não acessa assets; a tela chama util diretamente com valores do ProfileRepository.
    return out;
  }
}

import 'dart:convert';
import 'package:drift/drift.dart';
import '../core/db/app_db.dart';

class WeightSnapshot {
  final double current;
  final double target;
  final bool trendOk;
  WeightSnapshot({required this.current, required this.target, required this.trendOk});
}

class ProfileRepository {
  final AppDatabase db;
  ProfileRepository(this.db);

  Future<int> calorieTarget() async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    return p?.calorieTarget ?? 2000;
  }

  Future<void> upsertDefault() async {
    final existing = await (db.select(db.profiles)..limit(1)).get();
    if (existing.isEmpty) {
      await db.into(db.profiles).insert(const ProfilesCompanion());
    }
  }

  Future<WeightSnapshot> weightSnapshot() async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    final last = await (db.select(db.weightHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    final current = last?.kg ?? (p?.weight ?? 0);
    final target = p?.targetWeight ?? 0;
    final secondLast = await (db.select(db.weightHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1)
          ..offset(1))
        .getSingleOrNull();
    final trendOk = (target == 0)
        ? true
        : (secondLast == null ? true : ((target - current).abs() <= (target - secondLast.kg).abs()));
    return WeightSnapshot(current: current, target: target, trendOk: trendOk);
  }

  // Bests
  Future<Map<String, double?>> bests() async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    return {
      'supino': p?.best1RM_supino,
      'agachamento': p?.best1RM_agachamento,
      'terra': p?.best1RM_terra,
      'barra_fixa': p?.bestReps_barra_fixa,
    };
  }

  Future<void> updateBest(String key, double value) async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    if (p == null) return;
    final id = p.id;
    switch (key) {
      case 'supino':
        await (db.update(db.profiles)..where((t) => t.id.equals(id)))
            .write(ProfilesCompanion(best1RM_supino: Value(value)));
        break;
      case 'agachamento':
        await (db.update(db.profiles)..where((t) => t.id.equals(id)))
            .write(ProfilesCompanion(best1RM_agachamento: Value(value)));
        break;
      case 'terra':
        await (db.update(db.profiles)..where((t) => t.id.equals(id)))
            .write(ProfilesCompanion(best1RM_terra: Value(value)));
        break;
      case 'barra_fixa':
        await (db.update(db.profiles)..where((t) => t.id.equals(id)))
            .write(ProfilesCompanion(bestReps_barra_fixa: Value(value)));
        break;
    }
  }

  // Helpers
  static String dateOfNow() => DateTime.now().toIso8601String().substring(0, 10);
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

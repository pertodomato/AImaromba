import 'dart:convert';
import 'package:drift/drift.dart';
import '../core/db/app_db.dart';

class MealLogDTO {
  final int ts;
  final String date;
  final String mealId;
  final String mealName;
  final double grams;
  final double kcal, p, c, f;
  MealLogDTO({
    required this.ts,
    required this.date,
    required this.mealId,
    required this.mealName,
    required this.grams,
    required this.kcal,
    required this.p,
    required this.c,
    required this.f,
  });
}

class NutritionRepository {
  final AppDatabase db;
  NutritionRepository(this.db);

  Future<void> addFoodLog({
    String? mealId,
    required String mealName,
    required double grams,
    required double kcalPer100,
    required double pPer100,
    required double cPer100,
    required double fPer100,
    String source = 'manual',
    Map<String,dynamic>? extra,
  }) async {
    final factor = grams / 100.0;
    await db.into(db.foodLogs).insert(FoodLogsCompanion.insert(
      ts: DateTime.now().millisecondsSinceEpoch,
      date: DateTime.now().toIso8601String().substring(0,10),
      mealId: Value(mealId),
      mealName: mealName,
      grams: grams,
      kcal: kcalPer100 * factor,
      p: pPer100 * factor,
      c: cPer100 * factor,
      f: fPer100 * factor,
      source: Value(source),
      extraJson: Value(jsonEncode(extra ?? {})),
    ));
  }

  Future<List<MealLogDTO>> todayLogs() async {
    final d = DateTime.now().toIso8601String().substring(0,10);
    final rows = await (db.select(db.foodLogs)..where((t)=> t.date.equals(d))).get();
    return rows.map((r)=> MealLogDTO(
      ts: r.ts, date: r.date, mealId: r.mealId ?? '', mealName: r.mealName,
      grams: r.grams, kcal: r.kcal, p: r.p, c: r.c, f: r.f,
    )).toList();
  }

  Future<List<Map<String,dynamic>>> plannedForToday() async {
    // opcional: se você quiser integrar rotina de nutrição por dia/horário
    return const [];
  }

  Future<int> targetKcal() async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    return p?.calorieTarget ?? 2000;
  }

  Future<List<double>> lastDaysKcal(int days) async {
    final today = DateTime.now();
    final dates = List.generate(days, (i){
      final d = today.subtract(Duration(days: i));
      return DateTime(d.year, d.month, d.day).toIso8601String().substring(0,10);
    }).reversed.toList();

    final out = <double>[];
    for (final day in dates) {
      final rows = await (db.select(db.foodLogs)..where((t)=> t.date.equals(day))).get();
      final sum = rows.fold<double>(0, (s, r)=> s + r.kcal);
      out.add(sum);
    }
    return out;
  }

  Future<({double current, double target, bool trendOk})> weightSnapshot() async {
    final p = await (db.select(db.profiles)..limit(1)).getSingleOrNull();
    final last = await (db.select(db.weightHistory)
      ..orderBy([(t)=> OrderingTerm.desc(t.id)])
      ..limit(1)).getSingleOrNull();
    final current = last?.kg ?? (p?.weight ?? 0);
    final target = p?.targetWeight ?? 0;
    return (current: current, target: target, trendOk: true);
  }
}

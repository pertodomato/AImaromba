import 'package:hive/hive.dart';
import '../../models/meal.dart';
import '../../models/meal_log.dart';

class WeightSnap { // usado para o card de peso
  final double current, target; final bool trendOk;
  WeightSnap({required this.current, required this.target, required this.trendOk});
}

class NutritionRepository {
  Box get _foods => Hive.box('foods');              // TACO (lista em foods.items)
  Box get _meals => Hive.box('meals');              // suas refeições salvas (id -> Map)
  Box get _logs  => Hive.box('foodlogs');           // logs consumidos
  Box get _prof  => Hive.box('profile');            // meta kcal/peso
  Box get _rout  => Hive.box('nutrition_routines'); // rotinas

  // --------- CATALOG (buscar refeições)
  Future<Meal?> getMeal(String id) async {
    if (id.isEmpty) return null;
    if (_meals.containsKey(id)) return Meal.fromMap(_meals.get(id));

    final items = (_foods.get('items', defaultValue: const []) as List?) ?? const [];
    for (final it in items) {
      final m = Map.from(it as Map);
      if ((m['id'] ?? '') == id) return Meal.fromMap(m);
    }
    return null;
  }

  Future<void> saveMeal(Meal m) async {
    await _meals.put(m.id, m.toMap());
  }

  // --------- LOGS (consumo)
  Future<void> addLog({required Meal meal, required double grams}) async {
    final factor = grams / 100.0;
    final kcal = meal.kcalPer100 * factor;
    final p = meal.pPer100 * factor;
    final c = meal.cPer100 * factor;
    final f = meal.fPer100 * factor;

    final now = DateTime.now();
    final day = now.toIso8601String().substring(0, 10);

    await _logs.add(MealLog(
      ts: now.millisecondsSinceEpoch,
      date: day,
      mealId: meal.id,
      mealName: meal.name,
      grams: grams,
      kcal: kcal, p: p, c: c, f: f,
    ).toMap());
  }

  Future<List<MealLog>> todayLogs() async {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final out = <MealLog>[];
    for (final v in _logs.values) {
      if (v is Map && (v['date'] == day)) out.add(MealLog.fromMap(v));
    }
    out.sort((a,b) => a.ts.compareTo(b.ts));
    return out;
  }

  // --------- PLANEJADAS (rotina) para hoje
  Future<List<Map<String, dynamic>>> plannedForToday() async {
    final dow = DateTime.now().weekday % 7; // 1..7 -> 1..6,0
    final out = <Map<String, dynamic>>[];
    for (final v in _rout.values) {
      if (v is Map && v['items'] is List) {
        for (final it in v['items']) {
          final m = Map<String, dynamic>.from(it as Map);
          if ((m['dow'] as int?) == dow) {
            out.add(m);
          }
        }
      }
    }
    return out;
  }

  // --------- Métricas de meta/peso
  Future<double> targetKcal() async =>
      ((_prof.get('calorieTarget', defaultValue: 2000)) as num).toDouble();

  Future<List<double>> lastDaysKcal(int n) async {
    final today = DateTime.now();
    final map = <String, double>{};
    for (int i = 0; i < n; i++) {
      final d = today.subtract(Duration(days: n - 1 - i));
      map[d.toIso8601String().substring(0, 10)] = 0.0;
    }
    for (final v in _logs.values) {
      if (v is Map) {
        final day = (v['date'] ?? '').toString();
        if (map.containsKey(day)) {
          map[day] = (map[day]! + ((v['kcal'] ?? 0) as num).toDouble());
        }
      }
    }
    return map.values.toList();
  }

  Future<WeightSnap> weightSnapshot() async {
    final cur = ((_prof.get('weight',       defaultValue: 0)) as num).toDouble();
    final tgt = ((_prof.get('targetWeight', defaultValue: 0)) as num).toDouble();
    final target = await targetKcal();
    final avg = (await lastDaysKcal(7)).fold<double>(0, (a, b) => a + b) / 7.0;
    final delta = avg - target;
    bool trendOk = true;
    if (tgt > 0 && cur > 0) {
      if (cur > tgt) { // quer descer peso → déficit médio ajuda
        trendOk = delta < 0;
      } else if (cur < tgt) { // quer subir → superávit ajuda
        trendOk = delta > 0;
      }
    }
    return WeightSnap(current: cur, target: tgt, trendOk: trendOk);
  }
}

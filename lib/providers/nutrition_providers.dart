import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_log.dart';
import '../services/nutrition/nutrition_repository.dart';

class TodaySummary {
  final double kcal, p, c, f, targetKcal;
  TodaySummary({required this.kcal, required this.p, required this.c, required this.f, required this.targetKcal});
}
class WeightProgress {
  final double current, target; final bool trendOk;
  WeightProgress({required this.current, required this.target, required this.trendOk});
}

final repoProvider = Provider<NutritionRepository>((ref) => NutritionRepository());

// Hoje
final consumedMealsTodayProvider = FutureProvider<List<MealLog>>((ref) async => ref.read(repoProvider).todayLogs());
final plannedMealsTodayProvider  = FutureProvider<List<Map<String, dynamic>>>((ref) async => ref.read(repoProvider).plannedForToday());

final todaySummaryProvider = FutureProvider<TodaySummary>((ref) async {
  final r = ref.read(repoProvider);
  final logs = await r.todayLogs();
  double kcal=0,p=0,c=0,f=0;
  for (final l in logs) { kcal+=l.kcal; p+=l.p; c+=l.c; f+=l.f; }
  final target = await r.targetKcal();
  return TodaySummary(kcal: kcal, p: p, c: c, f: f, targetKcal: target);
});

// Semana (últimos 7 dias): soma(logs) - target
final weeklyDeltaProvider = FutureProvider<List<double>>((ref) async {
  final r = ref.read(repoProvider);
  final target = await r.targetKcal();
  final days = await r.lastDaysKcal(7);
  return days.map((k) => k - target).toList();
});

// Peso
final weightProgressProvider = FutureProvider<WeightProgress>((ref) async {
  final w = await ref.read(repoProvider).weightSnapshot();
  return WeightProgress(current: w.current, target: w.target, trendOk: w.trendOk);
});

// Helper para refresh em cascata:
extension NutritionInvalidate on Ref {
  void invalidateNutrition() {
    invalidate(consumedMealsTodayProvider);
    invalidate(plannedMealsTodayProvider);
    invalidate(todaySummaryProvider);
    invalidate(weeklyDeltaProvider);
    invalidate(weightProgressProvider);
  }
}

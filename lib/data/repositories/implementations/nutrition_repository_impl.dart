// lib/data/repositories/implementations/nutrition_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/nutrition_repository.dart';
import 'package:fitapp/domain/entities/nutrition.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final AppDatabase _db;
  NutritionRepositoryImpl(this._db);

  @override
  Future<void> saveFoodLog(FoodLogInput input) async {
    final companion = FoodLogsCompanion.insert(
      profileId: input.profileId,
      timestamp: DateTime.now(),
      source: input.source,
      kcal: input.kcal,
      protein: input.protein,
      carbs: input.carbs,
      fat: input.fat,
      notes: Value(input.notes),
      productBarcode: Value(input.barcode),
    );
    await _db.into(_db.foodLogs).insert(companion);
  }

  @override
  Stream<DailyNutrition> today(int profileId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logsQuery = _db.select(_db.foodLogs)
      ..where((tbl) => tbl.profileId.equals(profileId))
      ..where((tbl) => tbl.timestamp.isBetweenValues(startOfDay, endOfDay));
      
    final goalsQuery = _db.select(_db.nutritionGoals)
      ..where((tbl) => tbl.profileId.equals(profileId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);

    // Combina os dois streams
    return logsQuery.watch().combineLatest(goalsQuery.watchSingleOrNull(), (logs, goal) {
      double kcal = 0, p = 0, c = 0, f = 0;
      for (final log in logs) {
        kcal += log.kcal;
        p += log.protein;
        c += log.carbs;
        f += log.fat;
      }
      
      return DailyNutrition(
        consumedKcal: kcal,
        consumedProtein: p,
        consumedCarbs: c,
        consumedFat: f,
        targetKcal: goal?.kcal ?? 2000,
        targetProtein: goal?.protein ?? 150,
        targetCarbs: goal?.carbs ?? 250,
        targetFat: goal?.fat ?? 60,
        logs: logs.map((log) => FoodLogEntry(
          name: log.notes ?? 'Refeição',
          grams: 0, // O modelo de log não tem gramas, simplificando
          kcal: log.kcal,
          protein: log.protein,
          carbs: log.carbs,
          fat: log.fat,
        )).toList(),
      );
    });
  }
}
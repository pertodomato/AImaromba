import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/nutrition_repository.dart';
import 'package:fitapp/domain/entities/nutrition.dart' as domain;

class NutritionRepositoryImpl implements NutritionRepository {
  final AppDatabase _db;
  NutritionRepositoryImpl(this._db);

  @override
  Future<void> saveFoodLog(domain.FoodLogInput input) async {
    final companion = FoodLogsCompanion.insert(
      profileId: input.profileId,
      date: input.date,
      mealType: input.mealType.name,
      calories: input.calories,
      protein: input.protein,
      carbs: input.carbs,
      fat: input.fat,
      notes: Value(input.notes),
      productBarcode: Value(input.barcode),
    );
    await _db.into(_db.foodLogs).insert(companion);
  }

  @override
  Future<domain.DailyNutrition> getDaily(int profileId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final q = (_db.select(_db.foodLogs)
      ..where((t) => t.profileId.equals(profileId))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerThanValue(end)));

    final logs = await q.get();

    var cals = 0;
    var p = 0.0, c = 0.0, f = 0.0;
    for (final l in logs) {
      cals += l.calories;
      p += l.protein;
      c += l.carbs;
      f += l.fat;
    }

    return domain.DailyNutrition(
      date: start,
      calories: cals,
      protein: p,
      carbs: c,
      fat: f,
    );
  }
}

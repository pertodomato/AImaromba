// lib/data/repositories/nutrition_repository.dart

// Stubs de modelos
typedef ProfileId = int;
class FoodLogInput {}
class DailyNutrition {}

abstract interface class NutritionRepository {
  Future<void> saveFoodLog(FoodLogInput input); // usado por foto, texto e barcode
  Stream<DailyNutrition> today(ProfileId id);
}
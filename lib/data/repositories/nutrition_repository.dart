import 'package:fitapp/domain/entities/nutrition.dart' as domain;

abstract class NutritionRepository {
  Future<void> saveFoodLog(domain.FoodLogInput input);
  Future<domain.DailyNutrition> getDaily(int profileId, DateTime day);
}

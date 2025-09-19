// lib/core/models/diet_day_meal_plan_item.dart
import 'package:hive/hive.dart';
import 'meal.dart';

part 'diet_day_meal_plan_item.g.dart';

@HiveType(typeId: 29)
class DietDayMealPlanItem extends HiveObject {
  @HiveField(0)
  String id; // uuid
  @HiveField(1)
  String label; // cafe, almoco, lanche, jantar...
  @HiveField(2)
  Meal meal;
  @HiveField(3)
  double plannedGrams;

  DietDayMealPlanItem({
    required this.id,
    required this.label,
    required this.meal,
    required this.plannedGrams,
  });
}

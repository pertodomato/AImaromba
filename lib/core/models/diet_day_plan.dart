// lib/core/models/diet_day_plan.dart
import 'package:hive/hive.dart';
import 'diet_day_meal_plan_item.dart';

part 'diet_day_plan.g.dart';

@HiveType(typeId: 28)
class DietDayPlan extends HiveObject {
  @HiveField(0)
  String id; // uuid
  @HiveField(1)
  String dietDayId; // DietDay.id
  @HiveField(2)
  HiveList<DietDayMealPlanItem> items;

  DietDayPlan({
    required this.id,
    required this.dietDayId,
    required this.items,
  });
}

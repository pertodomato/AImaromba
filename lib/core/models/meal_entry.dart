import 'package:hive/hive.dart';
import 'meal.dart';

part 'meal_entry.g.dart';

@HiveType(typeId: 21)
class MealEntry extends HiveObject {
  @HiveField(0)
  String id; // uuid

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  String label; // café, almoço, jantar...

  @HiveField(3)
  Meal meal;

  @HiveField(4)
  double grams; // quantidade consumida

  MealEntry({
    required this.id,
    required this.dateTime,
    required this.label,
    required this.meal,
    required this.grams,
  });

  double get calories => meal.caloriesPer100g * grams / 100.0;
  double get protein => meal.proteinPer100g * grams / 100.0;
  double get carbs   => meal.carbsPer100g * grams / 100.0;
  double get fat     => meal.fatPer100g * grams / 100.0;
}

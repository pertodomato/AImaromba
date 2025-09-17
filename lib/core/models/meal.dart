import 'package:hive/hive.dart';

part 'meal.g.dart';

@HiveType(typeId: 20)
class Meal extends HiveObject {
  @HiveField(0)
  String id; // barcode ou uuid

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  /// macros por 100g
  @HiveField(3)
  double caloriesPer100g;

  @HiveField(4)
  double proteinPer100g;

  @HiveField(5)
  double carbsPer100g;

  @HiveField(6)
  double fatPer100g;

  Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });
}

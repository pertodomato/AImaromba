// lib/domain/entities/nutrition.dart
class FoodLogInput {
  final int profileId;
  final String source; // "photo", "text", "barcode", "manual"
  final double kcal, protein, carbs, fat;
  final String? notes;
  final String? barcode;

  FoodLogInput({
    required this.profileId,
    required this.source,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.notes,
    this.barcode,
  });
}

class FoodLogEntry {
  final String name;
  final double grams;
  final double kcal, protein, carbs, fat;
  
  FoodLogEntry({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class DailyNutrition {
  final double consumedKcal, consumedProtein, consumedCarbs, consumedFat;
  final double targetKcal, targetProtein, targetCarbs, targetFat;
  final List<FoodLogEntry> logs;

  DailyNutrition({
    required this.consumedKcal, required this.consumedProtein,
    required this.consumedCarbs, required this.consumedFat,
    required this.targetKcal, required this.targetProtein,
    required this.targetCarbs, required this.targetFat,
    required this.logs,
  });
}

class FoodProduct {
  final String barcode;
  final String name;
  final double kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g;

  FoodProduct({
    required this.barcode,
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });
}
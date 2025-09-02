import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final foodsProvider = Provider<List<Map>>((ref) {
  final items = Hive.box('foods').get('items', defaultValue: []) as List?;
  return (items ?? []).cast<Map>();
});

void addFoodLog({required Map food, required double grams}) {
  final kcal = (food['kcal'] as num).toDouble() * (grams/100.0);
  final protein = (food['protein'] as num).toDouble() * (grams/100.0);
  final carbs = (food['carbs'] as num).toDouble() * (grams/100.0);
  final fat = (food['fat'] as num).toDouble() * (grams/100.0);
  final today = DateTime.now().toIso8601String().substring(0,10);
  Hive.box('foodlogs').add({
    'date': today,
    'foodId': food['id'],
    'name': food['name'],
    'grams': grams,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat
  });
}

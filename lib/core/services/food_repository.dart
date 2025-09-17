import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:seu_app/core/models/meal.dart';

class FoodRepository {
  List<Meal> _tacoMeals = [];

  Future<void> loadTaco() async {
    final raw = await rootBundle.loadString('assets/taco.json');
    final List<dynamic> items = jsonDecode(raw);
    _tacoMeals = items.map((j) {
      return Meal(
        id: j['id'],
        name: j['name'],
        description: 'TACO',
        caloriesPer100g: (j['kcal'] as num).toDouble(),
        proteinPer100g: (j['protein'] as num).toDouble(),
        carbsPer100g: (j['carbs'] as num).toDouble(),
        fatPer100g: (j['fat'] as num).toDouble(),
      );
    }).toList();
  }

  /// Busca por nome (case-insensitive)
  List<Meal> searchByName(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _tacoMeals.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  Meal? getById(String id) {
    try {
      return _tacoMeals.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Meal> get allTaco => List.unmodifiable(_tacoMeals);
}

// REPLACE WHOLE FILE
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:seu_app/core/models/meal.dart';
import 'package:characters/characters.dart';

String _normalize(String s) {
  final lower = s.toLowerCase();
  final map = {
    'á':'a','à':'a','â':'a','ã':'a','ä':'a',
    'é':'e','è':'e','ê':'e','ë':'e',
    'í':'i','ì':'i','î':'i','ï':'i',
    'ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
    'ú':'u','ù':'u','û':'u','ü':'u',
    'ç':'c'
  };
  final sb = StringBuffer();
  for (final ch in lower.characters) {
    sb.write(map[ch] ?? ch);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class FoodRepository {
  List<Meal> _tacoMeals = [];
  late List<String> _normNames;

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
    _normNames = _tacoMeals.map((m) => _normalize(m.name)).toList();
  }

  /// Busca por nome com normalização e contains.
  List<Meal> searchByName(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return [];
    final out = <Meal>[];
    for (var i = 0; i < _tacoMeals.length; i++) {
      if (_normNames[i].contains(q)) out.add(_tacoMeals[i]);
    }
    return out;
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

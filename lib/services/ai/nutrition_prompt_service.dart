import 'dart:convert';
import '../ai/ai_core_service.dart';
import 'package:hive/hive.dart';

class NutritionAI {
  static String _systemMeal() => '''
Você gera **APENAS 1 objeto JSON** de refeição no schema:
{
  "name": "string",
  "desc": "string",
  "defaultPortion": number,
  "kcalPer100": number, "pPer100": number, "cPer100": number, "fPer100": number,
  "ingredients": [{"name":"string","grams":number}]
}
Regras: apenas JSON, números plausíveis, português.
''';

  static String _userMeal(String desc) => 'Descreva a refeição a partir de: "$desc" em JSON no schema acima.';

  static String _systemRoutine(List<Map> meals) {
    final cat = jsonEncode(meals.map((m)=> {'id': m['id'], 'name': m['name']}).toList());
    return '''
Gere **APENAS JSON** de rotina nutricional:
{
  "name":"string",
  "frequency":"weekly|biweekly|monthly",
  "items":[{"mealId":"string|opcional","mealName":"string|opcional","grams":number,"dow":int(0=dom..6=sab)}]
}
Use refeições existentes quando possível (CATALOGO abaixo), senão use "mealName".
CATALOGO: $cat
''';
  }
  static String _userRoutine(String goals) => 'Crie uma rotina a partir de: "$goals".';

  static Future<Map<String,dynamic>?> mealFromText(String description) async {
    try {
      final content = await AICore.chatOnceWithFallback(system: _systemMeal(), user: _userMeal(description));
      return Map<String,dynamic>.from(jsonDecode(content));
    } catch (_) { return null; }
  }

  static Future<Map<String,dynamic>?> routineFromText(String goals) async {
    final meals = Hive.box('meals').values.cast<Map>().toList();
    try {
      final content = await AICore.chatOnceWithFallback(system: _systemRoutine(meals), user: _userRoutine(goals));
      return Map<String,dynamic>.from(jsonDecode(content));
    } catch (_) { return null; }
  }
}

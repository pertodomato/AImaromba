import 'package:flutter/services.dart' show rootBundle;
import 'package:seu_app/core/models/meal.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/core/utils/json_safety.dart';
import 'package:uuid/uuid.dart';

class MealAIService {
  final LLMService llm;
  final _uuid = const Uuid();

  MealAIService(this.llm);

  Future<Meal?> fromText(String description) async {
    final template = await rootBundle.loadString('assets/prompts/meal_from_text.txt');
    final prompt = template.replaceAll('{meal_text}', description);
    final raw = await llm.generateResponse(prompt);
    final json = safeDecodeMap(raw);
    return _mealFromJson(json);
  }

  /// imageBase64: lista de strings base64 sem prefixo data:
  Future<Meal?> fromImage(List<String> imagesBase64, {String? extraText}) async {
    final template = await rootBundle.loadString('assets/prompts/meal_from_image.txt');
    final prompt = template.replaceAll('{extra}', extraText ?? '');
    final raw = await llm.generateResponse(prompt, imagesBase64: imagesBase64);
    final json = safeDecodeMap(raw);
    return _mealFromJson(json);
  }

  Meal? _mealFromJson(Map<String, dynamic> j) {
    final m = j['meal'];
    if (m == null) return null;
    return Meal(
      id: (m['id'] ?? _uuid.v4()).toString(),
      name: (m['name'] ?? 'Refeição').toString(),
      description: (m['description'] ?? '').toString(),
      caloriesPer100g: (m['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (m['protein_per_100g'] as num).toDouble(),
      carbsPer100g: (m['carbs_per_100g'] as num).toDouble(),
      fatPer100g: (m['fat_per_100g'] as num).toDouble(),
    );
  }
}

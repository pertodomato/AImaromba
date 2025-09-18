// lib/core/utils/meal_ai_service.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:fitapp/core/models/meal.dart' as core;
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/json_safety.dart';
import 'package:uuid/uuid.dart';

// Evita conflito de nomes com core/meal.dart
import 'package:fitapp/core/models/meal_estimate.dart' as est;

class MealAIService {
  final LLMService llm;
  final _uuid = const Uuid();

  MealAIService(this.llm);

  Future<core.Meal?> fromText(String description) async {
    final template = await rootBundle.loadString('assets/prompts/meal_from_text.txt');
    final prompt = template.replaceAll('{meal_text}', description);
    final raw = await llm.generateResponse(prompt);
    print('---- RESPOSTA CRUA DA IA (TEXTO) ----\n$raw\n---------------------------');
    final json = safeDecodeMap(raw);
    return _mealFromJson(json);
  }

  /// NOVO MÉTODO CORRIGIDO
  /// Retorna uma tupla contendo o resultado processado E a resposta JSON crua.
  Future<({({core.Meal meal, double grams})? result, String rawResponse})?>
      fromImageAutoWithRawResponse(
    List<String> imagesBase64, {
    String? extraText,
  }) async {
    final template = await rootBundle.loadString('assets/prompts/meal_from_image.txt');
    final prompt = template.replaceAll('{extra}', extraText ?? '');
    final raw = await llm.generateResponse(prompt, imagesBase64: imagesBase64);

    print('---- RESPOSTA CRUA DA IA (IMAGEM) ----\n$raw\n---------------------------');
    
    final result = _parseMealAndGrams(raw);
    
    return (result: result, rawResponse: raw);
  }


  /// Este método agora apenas chama o novo e extrai o resultado para manter compatibilidade.
  Future<({core.Meal meal, double grams})?> fromImageAuto(
    List<String> imagesBase64, {
    String? extraText,
  }) async {
      final response = await fromImageAutoWithRawResponse(imagesBase64, extraText: extraText);
      return response?.result;
  }

  // Lógica de parse extraída para ser reutilizável
  ({core.Meal meal, double grams})? _parseMealAndGrams(String rawResponse) {
    Map<String, dynamic> json;
    try {
      json = safeDecodeMap(rawResponse);
    } catch (e) {
      print('FALHA AO ANALISAR JSON: $e');
      return null;
    }

    double? grams;
    try {
      if (json['plate_estimate'] != null || json['components'] != null) {
        final compList = (json['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final plate = (json['plate_estimate'] as Map<String, dynamic>?) ?? const {};
        final comps = compList.map((e) => est.MealComponent.fromJson(e)).toList();
        final plateEst = plate.isNotEmpty
            ? est.PlateEstimate.fromJson(plate)
            : est.PlateEstimate.fromJson({
                'total_weight_g': comps.fold<double>(0, (a, c) => a + (c.estimatedWeightG)),
                'calories_total': 0, 'protein_total_g': 0, 'carbs_total_g': 0, 'fat_total_g': 0,
              });
        grams = plateEst.totalWeightG;
      }
    } catch (_) { /* ignora */ }

    grams ??= _tryParseNum(json['serving_weight_g']) ??
        _tryParseNum(json['total_weight_g']) ??
        _tryParseNum(json['estimated_weight_g']);

    grams ??= 300.0;

    final meal = _mealFromJson(json);
    if (meal == null) return null;

    return (meal: meal, grams: grams);
  }

  core.Meal? _mealFromJson(Map<String, dynamic> j) {
    final m = j['meal'];
    if (m == null) {
      print('FALHA NO SCHEMA: Chave "meal" não encontrada no JSON.');
      return null;
    }
    return core.Meal(
      id: (m['id'] ?? _uuid.v4()).toString(),
      name: (m['name'] ?? 'Refeição').toString(),
      description: (m['description'] ?? '').toString(),
      caloriesPer100g: _num(m['calories_per_100g']),
      proteinPer100g: _num(m['protein_per_100g']),
      carbsPer100g: _num(m['carbs_per_100g']),
      fatPer100g: _num(m['fat_per_100g']),
    );
  }

  double _num(dynamic v) => (v as num? ?? 0.0).toDouble();

  double? _tryParseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
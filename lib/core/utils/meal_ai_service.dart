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
    final json = safeDecodeMap(raw);
    return _mealFromJson(json);
  }

  /// Mantido p/ compatibilidade (retorna só o alimento).
  Future<core.Meal?> fromImage(List<String> imagesBase64, {String? extraText}) async {
    final res = await fromImageAuto(imagesBase64, extraText: extraText);
    return res == null ? null : res.meal;
  }

  /// NOVO: retorna alimento + gramas estimadas a partir da imagem (sem input do usuário).
  /// Usa, na ordem: plate_estimate.total_weight_g -> soma dos components.estimated_weight_g -> fallback 300g.
  Future<({core.Meal meal, double grams})?> fromImageAuto(
    List<String> imagesBase64, {
    String? extraText,
  }) async {
    final template = await rootBundle.loadString('assets/prompts/meal_from_image.txt');
    final prompt = template.replaceAll('{extra}', extraText ?? '');
    final raw = await llm.generateResponse(prompt, imagesBase64: imagesBase64);

    Map<String, dynamic> json;
    try {
      json = safeDecodeMap(raw);
    } catch (_) {
      return null;
    }

    // Tenta parse completo (MealEstimateResponse) se estrutura existir
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
                'calories_total': 0,
                'protein_total_g': 0,
                'carbs_total_g': 0,
                'fat_total_g': 0,
              });
        grams = plateEst.totalWeightG;
      }
    } catch (_) {
      // ignora e tenta outras rotas
    }

    // Se ainda não conseguiu, tenta campos comuns
    grams ??= _tryParseNum(json['serving_weight_g']) ??
        _tryParseNum(json['total_weight_g']) ??
        _tryParseNum(json['estimated_weight_g']);

    // Fallback duro para não travar o fluxo (plate típico)
    grams ??= 300.0;

    final meal = _mealFromJson(json);
    if (meal == null) return null;

    return (meal: meal, grams: grams);
  }

  core.Meal? _mealFromJson(Map<String, dynamic> j) {
    final m = j['meal'];
    if (m == null) return null;
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

  double _num(dynamic v) => (v as num).toDouble();

  double? _tryParseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

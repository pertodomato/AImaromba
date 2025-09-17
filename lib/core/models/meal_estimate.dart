// lib/models/meal_estimate.dart
// Modelos p/ resposta dos prompts meal_from_image / meal_from_text.

import 'dart:convert';

class Meal {
  final String id;
  final String name;
  final String description;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        caloriesPer100g: _toD(j['calories_per_100g']),
        proteinPer100g: _toD(j['protein_per_100g']),
        carbsPer100g: _toD(j['carbs_per_100g']),
        fatPer100g: _toD(j['fat_per_100g']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      };
}

class MealComponent {
  final String name;
  final double estimatedWeightG;

  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  // Totais calculados para a porção estimada
  final double caloriesTotal;
  final double proteinTotalG;
  final double carbsTotalG;
  final double fatTotalG;

  const MealComponent({
    required this.name,
    required this.estimatedWeightG,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.caloriesTotal,
    required this.proteinTotalG,
    required this.carbsTotalG,
    required this.fatTotalG,
  });

  factory MealComponent.fromJson(Map<String, dynamic> j) => MealComponent(
        name: j['name'] as String,
        estimatedWeightG: _toD(j['estimated_weight_g']),
        caloriesPer100g: _toD(j['calories_per_100g']),
        proteinPer100g: _toD(j['protein_per_100g']),
        carbsPer100g: _toD(j['carbs_per_100g']),
        fatPer100g: _toD(j['fat_per_100g']),
        caloriesTotal: _toD(j['calories_total']),
        proteinTotalG: _toD(j['protein_total_g']),
        carbsTotalG: _toD(j['carbs_total_g']),
        fatTotalG: _toD(j['fat_total_g']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_weight_g': estimatedWeightG,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
        'calories_total': caloriesTotal,
        'protein_total_g': proteinTotalG,
        'carbs_total_g': carbsTotalG,
        'fat_total_g': fatTotalG,
      };

  /// Recalcula os totais a partir de per_100g e peso estimado.
  MealComponent recomputeTotals() {
    final f = estimatedWeightG / 100.0;
    return MealComponent(
      name: name,
      estimatedWeightG: estimatedWeightG,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      caloriesTotal: _round1(caloriesPer100g * f),
      proteinTotalG: _round1(proteinPer100g * f),
      carbsTotalG: _round1(carbsPer100g * f),
      fatTotalG: _round1(fatPer100g * f),
    );
  }
}

class PlateEstimate {
  final double totalWeightG;
  final double caloriesTotal;
  final double proteinTotalG;
  final double carbsTotalG;
  final double fatTotalG;

  const PlateEstimate({
    required this.totalWeightG,
    required this.caloriesTotal,
    required this.proteinTotalG,
    required this.carbsTotalG,
    required this.fatTotalG,
  });

  factory PlateEstimate.fromJson(Map<String, dynamic> j) => PlateEstimate(
        totalWeightG: _toD(j['total_weight_g']),
        caloriesTotal: _toD(j['calories_total']),
        proteinTotalG: _toD(j['protein_total_g']),
        carbsTotalG: _toD(j['carbs_total_g']),
        fatTotalG: _toD(j['fat_total_g']),
      );

  Map<String, dynamic> toJson() => {
        'total_weight_g': totalWeightG,
        'calories_total': caloriesTotal,
        'protein_total_g': proteinTotalG,
        'carbs_total_g': carbsTotalG,
        'fat_total_g': fatTotalG,
      };

  /// Soma simples de componentes.
  static PlateEstimate fromComponents(List<MealComponent> comps) {
    final w = comps.fold<double>(0, (a, c) => a + c.estimatedWeightG);
    final cal = comps.fold<double>(0, (a, c) => a + c.caloriesTotal);
    final p = comps.fold<double>(0, (a, c) => a + c.proteinTotalG);
    final ch = comps.fold<double>(0, (a, c) => a + c.carbsTotalG);
    final f = comps.fold<double>(0, (a, c) => a + c.fatTotalG);
    return PlateEstimate(
      totalWeightG: _round1(w),
      caloriesTotal: _round1(cal),
      proteinTotalG: _round1(p),
      carbsTotalG: _round1(ch),
      fatTotalG: _round1(f),
    );
  }
}

class MealEstimateResponse {
  final Meal meal;
  final List<MealComponent> components;
  final PlateEstimate plateEstimate;

  const MealEstimateResponse({
    required this.meal,
    required this.components,
    required this.plateEstimate,
  });

  factory MealEstimateResponse.fromJson(Map<String, dynamic> j) =>
      MealEstimateResponse(
        meal: Meal.fromJson(j['meal'] as Map<String, dynamic>),
        components: (j['components'] as List<dynamic>)
            .map((e) => MealComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
        plateEstimate:
            PlateEstimate.fromJson(j['plate_estimate'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'meal': meal.toJson(),
        'components': components.map((e) => e.toJson()).toList(),
        'plate_estimate': plateEstimate.toJson(),
      };

  /// Recalcula plate_estimate a partir dos componentes (útil p/ validar/normalizar).
  MealEstimateResponse recomputePlateFromComponents() {
    final recomputed =
        PlateEstimate.fromComponents(components.map((c) => c.recomputeTotals()).toList());
    return MealEstimateResponse(
      meal: meal,
      components: components,
      plateEstimate: recomputed,
    );
  }

  static MealEstimateResponse parse(String jsonStr) =>
      MealEstimateResponse.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

double _toD(dynamic v) {
  if (v is int) return v.toDouble();
  if (v is double) return v;
  return double.parse(v.toString());
}

double _round1(double x) => (x * 10).round() / 10.0;

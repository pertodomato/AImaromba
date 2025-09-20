import 'package:fitapp/core/models/meal.dart' as core;

/// Componente estimado de um prato (usado pelos prompts meal_from_*).
class EstimatedMealComponent {
  final String name;
  final double estimatedWeightG;

  // macros por 100g (do componente)
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  // totais do componente (peso aplicado)
  final double caloriesTotal;
  final double proteinTotalG;
  final double carbsTotalG;
  final double fatTotalG;

  EstimatedMealComponent({
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

  factory EstimatedMealComponent.fromJson(Map<String, dynamic> json) {
    double _d(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return EstimatedMealComponent(
      name: (json['name'] ?? '').toString(),
      estimatedWeightG: _d(json['estimated_weight_g']),
      caloriesPer100g: _d(json['calories_per_100g']),
      proteinPer100g: _d(json['protein_per_100g']),
      carbsPer100g: _d(json['carbs_per_100g']),
      fatPer100g: _d(json['fat_per_100g']),
      caloriesTotal: _d(json['calories_total']),
      proteinTotalG: _d(json['protein_total_g']),
      carbsTotalG: _d(json['carbs_total_g']),
      fatTotalG: _d(json['fat_total_g']),
    );
  }

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
}

/// Totais estimados do prato consolidado.
class EstimatedPlateTotals {
  final double totalWeightG;
  final double caloriesTotal;
  final double proteinTotalG;
  final double carbsTotalG;
  final double fatTotalG;

  EstimatedPlateTotals({
    required this.totalWeightG,
    required this.caloriesTotal,
    required this.proteinTotalG,
    required this.carbsTotalG,
    required this.fatTotalG,
  });

  factory EstimatedPlateTotals.fromJson(Map<String, dynamic> json) {
    double _d(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return EstimatedPlateTotals(
      totalWeightG: _d(json['total_weight_g']),
      caloriesTotal: _d(json['calories_total']),
      proteinTotalG: _d(json['protein_total_g']),
      carbsTotalG: _d(json['carbs_total_g']),
      fatTotalG: _d(json['fat_total_g']),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_weight_g': totalWeightG,
        'calories_total': caloriesTotal,
        'protein_total_g': proteinTotalG,
        'carbs_total_g': carbsTotalG,
        'fat_total_g': fatTotalG,
      };
}

/// Resposta completa vinda do LLM para criação de um alimento consolidado.
///
/// Observação: o campo [meal] usa **core.Meal** (modelo Hive principal).
class MealEstimateResponse {
  final core.Meal meal;
  final List<EstimatedMealComponent> components;
  final EstimatedPlateTotals plateEstimate;

  MealEstimateResponse({
    required this.meal,
    required this.components,
    required this.plateEstimate,
  });

  /// Constrói a partir do JSON do prompt (chaves: "meal", "components", "plate_estimate").
  ///
  /// Mapeia diretamente os macros por 100g para o modelo Hive `core.Meal`.
  factory MealEstimateResponse.fromJson(Map<String, dynamic> json) {
    final mealJson = (json['meal'] as Map?)?.cast<String, dynamic>() ?? {};
    double _d(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    final coreMeal = core.Meal(
      // Se o seu core.Meal não tiver `id` no construtor, remova esta linha.
      // id: (mealJson['id'] ?? '').toString(),
      name: (mealJson['name'] ?? '').toString(),
      description: (mealJson['description'] ?? '').toString(),
      caloriesPer100g: _d(mealJson['calories_per_100g']),
      proteinPer100g: _d(mealJson['protein_per_100g']),
      carbsPer100g: _d(mealJson['carbs_per_100g']),
      fatPer100g: _d(mealJson['fat_per_100g']),
    );

    final comps = ((json['components'] as List?) ?? const [])
        .map((e) =>
            EstimatedMealComponent.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final plate = EstimatedPlateTotals.fromJson(
      (json['plate_estimate'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return MealEstimateResponse(
      meal: coreMeal,
      components: comps,
      plateEstimate: plate,
    );
  }

  Map<String, dynamic> toJson() => {
        'meal': {
          // Se `core.Meal` possuir `id`, inclua aqui.
          // 'id': meal.id,
          'name': meal.name,
          'description': meal.description,
          'calories_per_100g': meal.caloriesPer100g,
          'protein_per_100g': meal.proteinPer100g,
          'carbs_per_100g': meal.carbsPer100g,
          'fat_per_100g': meal.fatPer100g,
        },
        'components': components.map((e) => e.toJson()).toList(),
        'plate_estimate': plateEstimate.toJson(),
      };
}

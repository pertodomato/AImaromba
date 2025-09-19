// lib/features/3_planner/infrastructure/persistence/hive_diet_repo.dart
import 'package:hive/hive.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/diet_block.dart';

class HiveDietRepo {
  final Box<Meal> mealBox;
  final Box<DietDay> dayBox;
  final Box<DietRoutine> routineBox;
  final Box<DietBlock> blockBox;

  // Caso use planos diários detalhados:
  final Box? planBox;      // DietDayPlan
  final Box? planItemBox;  // DietDayMealPlanItem

  HiveDietRepo({
    required this.mealBox,
    required this.dayBox,
    required this.routineBox,
    required this.blockBox,
    this.planBox,
    this.planItemBox,
  });

  String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  // ---------- Meals ----------
  Meal upsertMeal({
    required String name,
    required String description,
    required num kcalPer100,
    required num pPer100,
    required num cPer100,
    required num fPer100,
  }) {
    final slug = _slug(name);
    for (final m in mealBox.values) {
      if (_slug(m.name) == slug) return m;
    }
    final meal = Meal()
      ..name = name
      ..description = description
      ..caloriesPer100g = kcalPer100.toDouble()
      ..proteinPer100g = pPer100.toDouble()
      ..carbsPer100g = cPer100.toDouble()
      ..fatPer100g = fPer100.toDouble();
    mealBox.add(meal);
    return meal;
  }

  // ---------- DietDay ----------
  DietDay upsertDietDay({
    required String name,
    required String description,
    required List<Meal> structure, // estrutura genérica (sem quantidades)
  }) {
    final slug = _slug(name);
    for (final d in dayBox.values) {
      if (_slug(d.name) == slug) return d;
    }
    final ddy = DietDay()
      ..name = name
      ..description = description
      ..mealIds = structure.map((m) => m.key as int).toList();
    dayBox.add(ddy);
    return ddy;
  }

  // ---------- DietBlock ----------
  DietBlock upsertDietBlock({
    required String name,
    required String description,
    required List<DietDay> daysOrdered,
  }) {
    final slug = _slug(name);
    for (final b in blockBox.values) {
      if (_slug(b.name) == slug) return b;
    }
    final block = DietBlock(
      slug: slug,
      name: name,
      description: description,
      daySlugs: daysOrdered.map((d) => _slug(d.name)).toList(),
    );
    blockBox.add(block);
    return block;
  }

  // ---------- DietRoutine ----------
  DietRoutine upsertDietRoutine({
    required String name,
    required String description,
    required String repetitionSchema,
    required List<DietBlock> sequence,
  }) {
    final slug = _slug(name);
    for (final r in routineBox.values) {
      if (_slug(r.name) == slug) {
        // Se já existir, você pode querer atualizar um campo "notes" etc.
        return r;
      }
    }
    final r = DietRoutine()
      ..name = name
      ..description = description
      ..repetitionSchema = repetitionSchema
      ..blockSlugs = sequence.map((b) => b.slug).toList();
    routineBox.add(r);
    return r;
  }
}

// lib/features/3_planner/infrastructure/persistence/hive_diet_repo.dart
import 'package:hive/hive.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

class HiveDietRepo {
  final Box<Meal> mealBox;
  final Box<DietDay> dayBox;
  final Box<DietRoutine> routineBox;
  final Box<DietBlock> blockBox;

  // Caso use planos diários detalhados (opcionais):
  final Box? planBox; // DietDayPlan
  final Box? planItemBox; // DietDayMealPlanItem

  HiveDietRepo({
    required this.mealBox,
    required this.dayBox,
    required this.routineBox,
    required this.blockBox,
    this.planBox,
    this.planItemBox,
  });

  // ---------- Meals ----------
  Meal upsertMeal({
    required String name,
    required String description,
    required num kcalPer100,
    required num pPer100,
    required num cPer100,
    required num fPer100,
  }) {
    final s = toSlug(name);
    for (final m in mealBox.values) {
      if (toSlug(m.name) == s) return m;
    }

    final meal = Meal(
      id: s,
      name: name,
      description: description,
      caloriesPer100g: kcalPer100.toDouble(),
      proteinPer100g: pPer100.toDouble(),
      carbsPer100g: cPer100.toDouble(),
      fatPer100g: fPer100.toDouble(),
    );

    mealBox.put(meal.id, meal);
    return meal;
  }

  // ---------- DietDay ----------
  DietDay upsertDietDay({
    required String name,
    required String description,
    required List<Meal> structure, // estrutura genérica (sem quantidades)
  }) {
    final s = toSlug(name);
    for (final d in dayBox.values) {
      if (toSlug(d.name) == s) return d;
    }

    // Model DietDay não tem lista de refeições; mantenha simples.
    final ddy = DietDay(
      id: s,
      name: name,
      description: description,
    );

    dayBox.put(ddy.id, ddy);
    return ddy;
  }

  // ---------- DietBlock ----------
  DietBlock upsertDietBlock({
    required String name,
    required String description,
    required List<DietDay> daysOrdered,
  }) {
    final s = toSlug(name);
    for (final b in blockBox.values) {
      if (b.slug == s) return b;
    }

    final block = DietBlock(
      slug: s,
      name: name,
      description: description,
      // Guarda apenas os slugs/ids ordenados dos dias
      daySlugs: daysOrdered.map((d) => toSlug(d.name)).toList(),
    );

    blockBox.put(block.slug, block);
    return block;
  }

  // ---------- DietRoutine ----------
  DietRoutine upsertDietRoutine({
    required String name,
    required String description,
    required String repetitionSchema,
    required List<DietBlock> sequence, // mantido para futura associação externa
  }) {
    final s = toSlug(name);
    for (final r in routineBox.values) {
      if (toSlug(r.name) == s) {
        return r;
      }
    }

    // Model DietRoutine exige startDate e HiveList<DietDay> days.
    final r = DietRoutine(
      id: s,
      name: name,
      description: description,
      startDate: DateTime.now(),
      repetitionSchema: repetitionSchema,
      days: HiveList<DietDay>(dayBox, objects: const []),
    );

    routineBox.put(r.id, r);
    return r;
  }
}

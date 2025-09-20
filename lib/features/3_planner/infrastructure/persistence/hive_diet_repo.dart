// lib/features/3_planner/infrastructure/persistence/hive_diet_repo.dart
import 'package:hive/hive.dart';
import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_routine_schedule.dart';
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

class HiveDietRepo {
  final Box<Meal> mealBox;
  final Box<DietDay> dietDayBox;
  final Box<DietBlock> dietBlockBox;
  final Box<DietRoutine> dietRoutineBox;
  final Box<DietRoutineSchedule> dietRoutineScheduleBox;
  final Box<DietDayPlan> dayPlanBox;
  final Box<DietDayMealPlanItem> planItemBox;

  HiveDietRepo({
    required this.mealBox,
    required this.dietDayBox,
    required this.dietBlockBox,
    required this.dietRoutineBox,
    required this.dietRoutineScheduleBox,
    required this.dayPlanBox,
    required this.planItemBox,
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
    final m = Meal(
      id: s,
      name: name,
      description: description,
      caloriesPer100g: kcalPer100.toDouble(),
      proteinPer100g: pPer100.toDouble(),
      carbsPer100g: cPer100.toDouble(),
      fatPer100g: fPer100.toDouble(),
    );
    mealBox.put(m.id, m);
    return m;
  }

  // ---------- DietDay (template do dia) ----------
  DietDay upsertDietDay({
    required String name,
    required String description,
    required List<Meal> structure, // catálogo base do dia (reutilizável)
  }) {
    final s = toSlug(name);
    for (final d in dietDayBox.values) {
      if (toSlug(d.name) == s) return d;
    }
    final day = DietDay(
      id: s,
      name: name,
      description: description,
      // Ajuste conforme seu modelo (structure/meals). Aqui usamos 'structure'.
      structure: HiveList<Meal>(mealBox, objects: structure),
    );
    dietDayBox.put(day.id, day);
    return day;
  }

  // ---------- DietBlock ----------
  DietBlock upsertDietBlock({
    required String name,
    required String description,
    required List<DietDay> daysOrdered, // 1–15
  }) {
    final s = toSlug(name);
    for (final b in dietBlockBox.values) {
      if (b.slug == s) return b;
    }
    final block = DietBlock(
      slug: s,
      name: name,
      description: description,
      daySlugs: daysOrdered.map((d) => toSlug(d.name)).toList(),
    );
    dietBlockBox.put(block.slug, block);
    return block;
  }

  // ---------- DietRoutine ----------
  DietRoutine upsertDietRoutine({
    required String name,
    required String description,
    required String repetitionSchema,
  }) {
    final s = toSlug(name);
    for (final r in dietRoutineBox.values) {
      if (toSlug(r.name) == s) return r;
    }
    final r = DietRoutine(
      id: s,
      name: name,
      description: description,
      // Se seu modelo não tiver esses campos, remova-os aqui.
      repetitionSchema: repetitionSchema,
      // NÃO preenche days na rotina (usa DietRoutineSchedule)
    );
    dietRoutineBox.put(r.id, r);
    return r;
  }

  // ---------- DietRoutineSchedule ----------
  DietRoutineSchedule upsertDietRoutineSchedule({
    required String routineSlug,
    required String repetitionSchema,
    required List<DietBlock> sequence,
  }) {
    final canonical = toSlug(routineSlug);

    // 1 rotina → 1 schedule
    final existing = dietRoutineScheduleBox.values
        .where((sch) => sch.routineSlug == canonical)
        .toList();

    if (existing.isNotEmpty) {
      final sch = existing.first;
      sch.blockSequence = sequence.map((b) => b.slug).toList();
      sch.repetitionSchema = repetitionSchema;
      sch.save();
      return sch;
    }

    final sch = DietRoutineSchedule(
      routineSlug: canonical,
      blockSequence: sequence.map((b) => b.slug).toList(),
      repetitionSchema: repetitionSchema,
    );

    dietRoutineScheduleBox.put(canonical, sch);
    return sch;
  }
}

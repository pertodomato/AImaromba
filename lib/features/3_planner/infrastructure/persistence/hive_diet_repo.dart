import 'package:hive/hive.dart';

import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';
import 'package:fitapp/core/models/diet_routine_schedule.dart';

import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';
import 'package:fitapp/core/services/hive_service.dart';

class HiveDietRepo {
  // Boxes
  final Box<Meal> mealsBox;
  final Box<DietDay> dietDaysBox;
  final Box<DietBlock> dietBlocksBox;
  final Box<DietRoutine> dietRoutinesBox;
  final Box<DietDayPlan> dietDayPlansBox;
  final Box<DietDayMealPlanItem> dietDayMealPlanItemsBox;
  final Box<DietRoutineSchedule> dietRoutineScheduleBox;

  // --- Campos-função para compatibilidade com chamadas ?.call no orchestrator ---
  Meal? Function(String slug) findMealBySlug;
  DietDayMealPlanItem? Function({
    required Meal meal,
    required String label,
    required double grams,
  }) createPlanItem;

  DietDayPlan Function({
    required DietDay day,
    required List<dynamic> items,
  }) upsertDietDayPlan;

  Map<String, num> Function(DietDayPlan plan) computePlanTotals;

  void Function(DietDayPlan plan, String note) annotatePlanNote;

  DietRoutineSchedule Function({
    required String routineSlug,
    required String repetitionSchema,
    required List<DietBlock> sequence,
    DateTime? endDate,
  }) upsertDietRoutineSchedule;

  HiveDietRepo({
    required this.mealsBox,
    required this.dietDaysBox,
    required this.dietBlocksBox,
    required this.dietRoutinesBox,
    required this.dietDayPlansBox,
    required this.dietDayMealPlanItemsBox,
    required this.dietRoutineScheduleBox,
  })  : findMealBySlug = _noopFindMeal,
        createPlanItem = _noopCreatePlanItem,
        upsertDietDayPlan = _noopUpsertPlan,
        computePlanTotals = _noopComputeTotals,
        annotatePlanNote = _noopAnnotatePlanNote,
        upsertDietRoutineSchedule = _noopUpsertSchedule {
    // Conecta os campos-função às implementações reais.
    findMealBySlug = _findMealBySlug;
    createPlanItem = ({
      required Meal meal,
      required String label,
      required double grams,
    }) =>
        _createPlanItem(meal: meal, label: label, grams: grams);

    upsertDietDayPlan = ({
      required DietDay day,
      required List<dynamic> items,
    }) =>
        _upsertDietDayPlan(day: day, items: items);

    computePlanTotals = (DietDayPlan plan) => _computePlanTotals(plan);

    annotatePlanNote = (plan, note) => _annotatePlanNote(plan, note);

    upsertDietRoutineSchedule = ({
      required String routineSlug,
      required String repetitionSchema,
      required List<DietBlock> sequence,
      DateTime? endDate,
    }) =>
        _upsertDietRoutineSchedule(
          routineSlug: routineSlug,
          repetitionSchema: repetitionSchema,
          sequence: sequence,
          endDate: endDate,
        );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String _ensureUniqueKey(Box box, String baseKey) {
    if (!box.containsKey(baseKey)) return baseKey;
    var i = 2;
    while (box.containsKey('$baseKey-$i')) {
      i++;
    }
    return '$baseKey-$i';
  }

  static String _safeName(String name) => (name.isEmpty ? 'item' : name);

  static Meal? _noopFindMeal(String slug) => null;

  // ---------------------------------------------------------------------------
  // Meals
  // ---------------------------------------------------------------------------
  Meal upsertMeal({
    required String name,
    String description = '',
    required double kcalPer100,
    required double pPer100,
    required double cPer100,
    required double fPer100,
  }) {
    final nm = _safeName(name);
    final slug = toSlug(nm);

    // Se já existir: atualiza
    Meal? existing;
    if (mealsBox.containsKey(slug)) {
      existing = mealsBox.get(slug);
    } else {
      // Procurar por ID igual ao slug também
      try {
        existing = mealsBox.values.firstWhere(
          (m) => toSlug(m.name) == slug || m.id == slug,
        );
      } catch (_) {
        existing = null;
      }
    }

    if (existing != null && existing.isInBox) {
      existing
        ..name = nm
        ..description = description
        ..caloriesPer100g = kcalPer100
        ..proteinPer100g = pPer100
        ..carbsPer100g = cPer100
        ..fatPer100g = fPer100;
      // ignore: discarded_futures
      existing.save();
      // LOG
      // ignore: avoid_print
      print('.. updated MEAL: ${existing.id} | ${existing.name}');
      return existing;
    } else {
      // garantir key única
      final key = _ensureUniqueKey(mealsBox, slug);
      final created = Meal(
        id: slug,
        name: nm,
        description: description,
        caloriesPer100g: kcalPer100,
        proteinPer100g: pPer100,
        carbsPer100g: cPer100,
        fatPer100g: fPer100,
      );
      // ignore: discarded_futures
      mealsBox.put(key, created);
      // LOG
      // ignore: avoid_print
      print('.. saved MEAL: ${created.id} | ${created.name}');
      return created;
    }
  }

  // Implementação real ligada no construtor
  Meal? _findMealBySlug(String slug) {
    if (mealsBox.containsKey(slug)) return mealsBox.get(slug);
    try {
      return mealsBox.values.firstWhere(
        (m) => toSlug(m.name) == slug || m.id == slug,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // DietDay
  // ---------------------------------------------------------------------------
  DietDay upsertDietDay({
    required String name,
    String description = '',
    List<Meal>? structure, // compat
  }) {
    final nm = _safeName(name);
    final slug = toSlug(nm);

    DietDay? day;
    if (dietDaysBox.containsKey(slug)) {
      day = dietDaysBox.get(slug);
      day!
        ..name = nm
        ..description = description;
      // ignore: discarded_futures
      day.save();
      // LOG
      // ignore: avoid_print
      print('.. updated DIET DAY: ${day.id} | ${day.name}');
      return day;
    }

    // garantir key única
    final key = _ensureUniqueKey(dietDaysBox, slug);
    final created = DietDay(
      id: key,
      name: nm,
      description: description,
    );
    // ignore: discarded_futures
    dietDaysBox.put(key, created);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET DAY: ${created.id} | ${created.name}');
    return created;
  }

  // ---------------------------------------------------------------------------
  // DietBlock
  // ---------------------------------------------------------------------------
  DietBlock upsertDietBlock({
    required String name,
    String description = '',
    required List<DietDay> daysOrdered,
  }) {
    final nm = _safeName(name);
    final slug = toSlug(nm);

    final daySlugs = daysOrdered.map((d) => d.id).toList();

    DietBlock? block;
    if (dietBlocksBox.containsKey(slug)) {
      block = dietBlocksBox.get(slug);
      block!
        ..name = nm
        ..description = description
        ..daySlugs = daySlugs;
      // ignore: discarded_futures
      block.save();
      // LOG
      // ignore: avoid_print
      print('.. updated DIET BLOCK: ${block.slug} | ${block.name} (days: ${daySlugs.length})');
      return block;
    }

    final key = _ensureUniqueKey(dietBlocksBox, slug);
    final created = DietBlock(
      slug: key,
      name: nm,
      description: description,
      daySlugs: daySlugs,
    );
    // ignore: discarded_futures
    dietBlocksBox.put(key, created);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET BLOCK: ${created.slug} | ${created.name} (days: ${daySlugs.length})');
    return created;
  }

  // ---------------------------------------------------------------------------
  // DietRoutine (não popular days; schedule separado)
  // ---------------------------------------------------------------------------
  DietRoutine upsertDietRoutine({
    required String name,
    String description = '',
    required String repetitionSchema,
    List<DietBlock> sequence = const [],
  }) {
    final nm = _safeName(name);
    final slug = toSlug(nm);

    if (dietRoutinesBox.containsKey(slug)) {
      final r = dietRoutinesBox.get(slug)!;
      r
        ..name = nm
        ..description = description
        ..repetitionSchema = repetitionSchema;
      // ignore: discarded_futures
      r.save();
      // LOG
      // ignore: avoid_print
      print('.. updated DIET ROUTINE: ${r.id} | ${r.name}');
      return r;
    }

    final key = _ensureUniqueKey(dietRoutinesBox, slug);
    final emptyDays = HiveList<DietDay>(dietDaysBox, objects: const []);
    final created = DietRoutine(
      id: key,
      name: nm,
      description: description,
      startDate: DateTime.now(),
      repetitionSchema: repetitionSchema,
      days: emptyDays, // não usar; ordem fica no schedule
    );
    // ignore: discarded_futures
    dietRoutinesBox.put(key, created);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET ROUTINE: ${created.id} | ${created.name}');
    return created;
  }

  // ---------------------------------------------------------------------------
  // DietRoutineSchedule
  // ---------------------------------------------------------------------------
  static DietRoutineSchedule _noopUpsertSchedule({
    required String routineSlug,
    required String repetitionSchema,
    required List<DietBlock> sequence,
    DateTime? endDate,
  }) {
    throw UnimplementedError();
  }

  DietRoutineSchedule _upsertDietRoutineSchedule({
    required String routineSlug,
    required String repetitionSchema,
    required List<DietBlock> sequence,
    DateTime? endDate,
  }) {
    final canonical = toSlug(routineSlug);
    final blockSeq = sequence.map((b) => b.slug).toList();

    // Tenta achar schedule existente por rotina
    final existing = dietRoutineScheduleBox.values
        .where((s) => s.routineSlug == canonical)
        .toList();

    if (existing.isNotEmpty) {
      final sch = existing.first;
      sch
        ..blockSequence = blockSeq
        ..repetitionSchema = repetitionSchema
        ..endDate = endDate ?? sch.endDate;
      // ignore: discarded_futures
      sch.save();
      // LOG
      // ignore: avoid_print
      print('.. updated DIET SCHEDULE: $canonical -> $blockSeq');
      return sch;
    }

    final sch = DietRoutineSchedule(
      routineSlug: canonical,
      blockSequence: blockSeq,
      repetitionSchema: repetitionSchema,
      endDate: endDate,
    );
    // Usa a própria slug como key principal do schedule
    // ignore: discarded_futures
    dietRoutineScheduleBox.put(canonical, sch);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET SCHEDULE: $canonical -> $blockSeq');
    return sch;
  }

  // ---------------------------------------------------------------------------
  // DietDayPlan + Items (MealPlanItem)
  // ---------------------------------------------------------------------------
  static DietDayMealPlanItem? _noopCreatePlanItem({
    required Meal meal,
    required String label,
    required double grams,
  }) {
    return null;
  }

  DietDayMealPlanItem _createPlanItem({
    required Meal meal,
    required String label,
    required double grams,
  }) {
    final base = 'ddmpi-${toSlug(label)}';
    final key = _ensureUniqueKey(dietDayMealPlanItemsBox, base);
    final item = DietDayMealPlanItem(
      id: key,
      label: label,
      meal: meal,
      plannedGrams: grams,
    );
    // ignore: discarded_futures
    dietDayMealPlanItemsBox.put(key, item);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET PLAN ITEM: ${item.id} | ${item.label} (${grams} g)');
    return item;
  }

  static DietDayPlan _noopUpsertPlan({
    required DietDay day,
    required List<dynamic> items,
  }) {
    throw UnimplementedError();
  }

  DietDayPlan _upsertDietDayPlan({
    required DietDay day,
    required List<dynamic> items,
  }) {
    final typedItems = items.whereType<DietDayMealPlanItem>().toList(growable: false);

    // Garante que todos os itens estão salvos (têm key)
    for (final it in typedItems) {
      if (!it.isInBox) {
        final k = _ensureUniqueKey(
          dietDayMealPlanItemsBox,
          it.id.isNotEmpty ? it.id : 'ddmpi-${DateTime.now().microsecondsSinceEpoch}',
        );
        // ignore: discarded_futures
        dietDayMealPlanItemsBox.put(k, it);
      }
    }

    // Reaproveita um plano existente do dia, se houver
    final existing = dietDayPlansBox.values.where((p) => p.dietDayId == day.id).toList();

    final hiveList = HiveList<DietDayMealPlanItem>(
      dietDayMealPlanItemsBox,
      objects: typedItems,
    );

    if (existing.isNotEmpty) {
      final plan = existing.first;
      plan.items = hiveList;
      // ignore: discarded_futures
      plan.save();
      // LOG
      // ignore: avoid_print
      print('.. updated DIET DAY PLAN: ${plan.id} (${typedItems.length} items)');
      return plan;
    }

    final planKey = _ensureUniqueKey(
      dietDayPlansBox,
      'plan-${toSlug(day.name)}-${day.id}',
    );
    final plan = DietDayPlan(
      id: planKey,
      dietDayId: day.id,
      items: hiveList,
    );
    // ignore: discarded_futures
    dietDayPlansBox.put(planKey, plan);
    // LOG
    // ignore: avoid_print
    print('.. saved DIET DAY PLAN: ${plan.id} (${typedItems.length} items)');
    return plan;
  }

  static Map<String, num> _noopComputeTotals(DietDayPlan plan) => const {};

  Map<String, num> _computePlanTotals(DietDayPlan plan) {
    double cal = 0, p = 0, c = 0, f = 0;

    for (final item in plan.items) {
      final grams = item.plannedGrams;
      final m = item.meal;

      cal += m.caloriesPer100g * grams / 100.0;
      p += m.proteinPer100g * grams / 100.0;
      c += m.carbsPer100g * grams / 100.0;
      f += m.fatPer100g * grams / 100.0;
    }

    return <String, num>{
      'calories': cal,
      'protein_g': p,
      'carbs_g': c,
      'fat_g': f,
    };
  }

  static void _noopAnnotatePlanNote(DietDayPlan plan, String note) {}

  void _annotatePlanNote(DietDayPlan plan, String note) {
    // Sem campo de notas; log simples
    // ignore: avoid_print
    print('[DietPlan Note] ${plan.id}: $note');
  }

  // ---------------------------------------------------------------------------
  // Fábrica a partir do HiveService (opcional, facilita DI)
  // ---------------------------------------------------------------------------
  factory HiveDietRepo.fromService(HiveService s) => HiveDietRepo(
        mealsBox: s.mealsBox,
        dietDaysBox: s.dietDaysBox,
        dietBlocksBox: s.dietBlocksBox,
        dietRoutinesBox: s.dietRoutinesBox,
        dietDayPlansBox: s.dietDayPlansBox,
        dietDayMealPlanItemsBox: s.dietDayMealPlanItemsBox,
        dietRoutineScheduleBox: s.dietRoutineSchedulesBox,
      );
}

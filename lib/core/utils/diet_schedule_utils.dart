import 'package:fitapp/core/constants/diet_weight_goal.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_routine_schedule.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

class DietScheduleTarget {
  const DietScheduleTarget({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.dayName,
    this.blockName,
    this.weightGoal,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? dayName;
  final String? blockName;
  final String? weightGoal;

  bool get hasCalorieGoal => calories > 0;
  String? get weightGoalLabel => DietWeightGoal.label(weightGoal);

  List<String> get labelParts {
    final parts = <String>[];
    if (blockName != null && blockName!.isNotEmpty) {
      parts.add(blockName!);
    }
    if (dayName != null && dayName!.isNotEmpty) {
      parts.add(dayName!);
    }
    final goalLabel = weightGoalLabel;
    if (goalLabel != null && goalLabel.isNotEmpty) {
      parts.add(goalLabel);
    }
    return parts;
  }

  String? get displayLabel => labelParts.isEmpty ? null : labelParts.join(' • ');
}

class DietScheduleUtils {
  static const int _defaultDurationDays = 180;

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static T? _firstWhereOrNull<T>(Iterable<T> source, bool Function(T) test) {
    for (final element in source) {
      if (test(element)) return element;
    }
    return null;
  }

  static DateTime? _resolveEndDate({
    required DateTime? start,
    required DateTime? storedEnd,
  }) {
    if (start == null) return null;
    final startOnly = _dateOnly(start);
    if (storedEnd != null) {
      final normalized = _dateOnly(storedEnd);
      if (!normalized.isBefore(startOnly)) {
        return normalized;
      }
    }
    return _dateOnly(startOnly.add(const Duration(days: _defaultDurationDays - 1)));
  }

  static DietScheduleTarget? resolveDailyTarget({
    required HiveService hive,
    DateTime? referenceDate,
  }) {
    final targetDate = _dateOnly(referenceDate ?? DateTime.now());
    final routines = hive.dietRoutinesBox.values.toList();
    if (routines.isEmpty) return null;

    DietScheduleTarget? selectedTarget;
    DateTime? selectedStart;

    for (final routine in routines) {
      final start = _dateOnly(routine.startDate);
      if (targetDate.isBefore(start)) {
        continue;
      }

      final slug = toSlug(routine.name);
      final schedules = hive.dietRoutineSchedulesBox;
      DietRoutineSchedule? schedule = schedules.get(slug);
      schedule ??= _firstWhereOrNull(
        schedules.values,
        (s) => s.routineSlug == slug || s.routineSlug == routine.id,
      );
      if (schedule == null) {
        continue;
      }

      final end = _resolveEndDate(start: start, storedEnd: schedule.endDate);
      if (end != null && targetDate.isAfter(end)) {
        continue;
      }

      final blocksBox = hive.dietBlocksBox;
      final blocksSequence = <DietBlock>[];
      for (final blockSlug in schedule.blockSequence) {
        final block = blocksBox.get(blockSlug) ??
            _firstWhereOrNull(blocksBox.values, (b) => b.slug == blockSlug);
        if (block == null || block.daySlugs.isEmpty) continue;
        blocksSequence.add(block);
      }
      if (blocksSequence.isEmpty) {
        continue;
      }

      final cycleLength = blocksSequence.fold<int>(0, (sum, block) => sum + block.daySlugs.length);
      if (cycleLength == 0) {
        continue;
      }

      final diff = targetDate.difference(start).inDays;
      if (diff < 0) continue;
      final cycleIndex = diff % cycleLength;

      DietBlock? activeBlock;
      String? daySlug;
      var cursor = 0;
      for (final block in blocksSequence) {
        final len = block.daySlugs.length;
        if (cycleIndex < cursor + len) {
          activeBlock = block;
          daySlug = block.daySlugs[cycleIndex - cursor];
          break;
        }
        cursor += len;
      }

      if (daySlug == null) {
        continue;
      }

      final dietDay = hive.dietDaysBox.get(daySlug) ??
          _firstWhereOrNull(hive.dietDaysBox.values, (d) => d.id == daySlug);
      if (dietDay == null) {
        continue;
      }

      final plan = _firstWhereOrNull(
        hive.dietDayPlansBox.values,
        (DietDayPlan p) => p.dietDayId == dietDay.id,
      );

      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;

      if (plan != null) {
        for (final item in plan.items) {
          if (item is! DietDayMealPlanItem) continue;
          final meal = item.meal;
          final grams = item.plannedGrams;
          calories += meal.caloriesPer100g * grams / 100.0;
          protein += meal.proteinPer100g * grams / 100.0;
          carbs += meal.carbsPer100g * grams / 100.0;
          fat += meal.fatPer100g * grams / 100.0;
        }
      }

      final weightGoal = activeBlock != null
          ? hive.dietBlockGoalsBox.get(activeBlock.slug) ??
              hive.dietBlockGoalsBox.get(toSlug(activeBlock.name))
          : null;

      final candidate = DietScheduleTarget(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        dayName: dietDay.name,
        blockName: activeBlock?.name,
        weightGoal: weightGoal,
      );

      if (selectedStart == null || start.isAfter(selectedStart)) {
        selectedStart = start;
        selectedTarget = candidate;
      }
    }

    return selectedTarget;
  }

  static double calorieBiasForGoal(String? goal) =>
      DietWeightGoal.calorieBias(goal);
}

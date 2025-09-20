import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:flutter/foundation.dart' show kIsWeb;

// MODELS
import 'package:fitapp/core/models/user_profile.dart';
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';

import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/meal_entry.dart';
import 'package:fitapp/core/models/weight_entry.dart';

import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';
import 'package:fitapp/core/models/diet_routine_schedule.dart';

import 'package:fitapp/core/models/workout_set_entry.dart';
import 'package:fitapp/core/models/workout_session_log.dart';

class HiveService {
  // nomes FIXOS
  static const _userProfileBoxName = 'user_profile';

  static const _exercisesBoxName = 'exercises';
  static const _workoutSessionsBoxName = 'workout_sessions';
  static const _workoutDaysBoxName = 'workout_days';
  static const _workoutBlocksBoxName = 'workout_blocks';
  static const _workoutRoutinesBoxName = 'workout_routines';
  static const _workoutRoutineSchedulesBoxName = 'workout_routine_schedules';
  // alias antigo usado em telas
  static const _routineSchedulesAlias = 'routine_schedules';

  static const _mealsBoxName = 'meals';
  static const _mealEntriesBoxName = 'meal_entries';
  static const _weightEntriesBoxName = 'weight_entries';

  static const _dietDaysBoxName = 'diet_days';
  static const _dietBlocksBoxName = 'diet_blocks';
  static const _dietRoutinesBoxName = 'diet_routines';
  static const _dietDayPlansBoxName = 'diet_day_plans';
  static const _dietDayMealPlanItemsBoxName = 'diet_day_meal_plan_items';
  static const _dietRoutineSchedulesBoxName = 'diet_routine_schedules';

  static const _workoutSetEntriesBoxName = 'workout_set_entries';
  static const _workoutSessionLogsBoxName = 'workout_session_logs';

  Future<void> init() async {
    if (!kIsWeb) {
      final dir = await pp.getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }
    await _openTypedBoxesOnce();
  }

  Future<void> _openTypedBoxesOnce() async {
    // Perfil
    if (!Hive.isBoxOpen(_userProfileBoxName)) {
      await Hive.openBox<UserProfile>(_userProfileBoxName);
    }

    // Workout
    if (!Hive.isBoxOpen(_exercisesBoxName)) {
      await Hive.openBox<Exercise>(_exercisesBoxName);
    }
    if (!Hive.isBoxOpen(_workoutSessionsBoxName)) {
      await Hive.openBox<WorkoutSession>(_workoutSessionsBoxName);
    }
    if (!Hive.isBoxOpen(_workoutDaysBoxName)) {
      await Hive.openBox<WorkoutDay>(_workoutDaysBoxName);
    }
    if (!Hive.isBoxOpen(_workoutBlocksBoxName)) {
      await Hive.openBox<WorkoutBlock>(_workoutBlocksBoxName);
    }
    if (!Hive.isBoxOpen(_workoutRoutinesBoxName)) {
      await Hive.openBox<WorkoutRoutine>(_workoutRoutinesBoxName);
    }
    if (!Hive.isBoxOpen(_workoutRoutineSchedulesBoxName)) {
      await Hive.openBox<WorkoutRoutineSchedule>(_workoutRoutineSchedulesBoxName);
    }

    // Workout – logs/sets
    if (!Hive.isBoxOpen(_workoutSetEntriesBoxName)) {
      await Hive.openBox<WorkoutSetEntry>(_workoutSetEntriesBoxName);
    }
    if (!Hive.isBoxOpen(_workoutSessionLogsBoxName)) {
      await Hive.openBox<WorkoutSessionLog>(_workoutSessionLogsBoxName);
    }

    // Diet
    if (!Hive.isBoxOpen(_mealsBoxName)) {
      await Hive.openBox<Meal>(_mealsBoxName);
    }
    if (!Hive.isBoxOpen(_mealEntriesBoxName)) {
      await Hive.openBox<MealEntry>(_mealEntriesBoxName);
    }
    if (!Hive.isBoxOpen(_weightEntriesBoxName)) {
      await Hive.openBox<WeightEntry>(_weightEntriesBoxName);
    }

    if (!Hive.isBoxOpen(_dietDaysBoxName)) {
      await Hive.openBox<DietDay>(_dietDaysBoxName);
    }
    if (!Hive.isBoxOpen(_dietBlocksBoxName)) {
      await Hive.openBox<DietBlock>(_dietBlocksBoxName);
    }
    if (!Hive.isBoxOpen(_dietRoutinesBoxName)) {
      await Hive.openBox<DietRoutine>(_dietRoutinesBoxName);
    }
    if (!Hive.isBoxOpen(_dietDayPlansBoxName)) {
      await Hive.openBox<DietDayPlan>(_dietDayPlansBoxName);
    }
    if (!Hive.isBoxOpen(_dietDayMealPlanItemsBoxName)) {
      await Hive.openBox<DietDayMealPlanItem>(_dietDayMealPlanItemsBoxName);
    }
    if (!Hive.isBoxOpen(_dietRoutineSchedulesBoxName)) {
      await Hive.openBox<DietRoutineSchedule>(_dietRoutineSchedulesBoxName);
    }
  }

  // GETTERS TIPADOS
  Box<UserProfile> get userProfileBox => Hive.box<UserProfile>(_userProfileBoxName);

  Box<Exercise> get exercisesBox => Hive.box<Exercise>(_exercisesBoxName);
  Box<WorkoutSession> get workoutSessionsBox => Hive.box<WorkoutSession>(_workoutSessionsBoxName);
  Box<WorkoutDay> get workoutDaysBox => Hive.box<WorkoutDay>(_workoutDaysBoxName);
  Box<WorkoutBlock> get workoutBlocksBox => Hive.box<WorkoutBlock>(_workoutBlocksBoxName);
  Box<WorkoutRoutine> get workoutRoutinesBox => Hive.box<WorkoutRoutine>(_workoutRoutinesBoxName);
  Box<WorkoutRoutineSchedule> get workoutRoutineSchedulesBox =>
      Hive.box<WorkoutRoutineSchedule>(_workoutRoutineSchedulesBoxName);

  Box<WorkoutSetEntry> get workoutSetEntriesBox => Hive.box<WorkoutSetEntry>(_workoutSetEntriesBoxName);
  Box<WorkoutSessionLog> get workoutSessionLogsBox => Hive.box<WorkoutSessionLog>(_workoutSessionLogsBoxName);

  Box<Meal> get mealsBox => Hive.box<Meal>(_mealsBoxName);
  Box<MealEntry> get mealEntriesBox => Hive.box<MealEntry>(_mealEntriesBoxName);
  Box<WeightEntry> get weightEntriesBox => Hive.box<WeightEntry>(_weightEntriesBoxName);

  Box<DietDay> get dietDaysBox => Hive.box<DietDay>(_dietDaysBoxName);
  Box<DietBlock> get dietBlocksBox => Hive.box<DietBlock>(_dietBlocksBoxName);
  Box<DietRoutine> get dietRoutinesBox => Hive.box<DietRoutine>(_dietRoutinesBoxName);
  Box<DietDayPlan> get dietDayPlansBox => Hive.box<DietDayPlan>(_dietDayPlansBoxName);
  Box<DietDayMealPlanItem> get dietDayMealPlanItemsBox =>
      Hive.box<DietDayMealPlanItem>(_dietDayMealPlanItemsBoxName);
  Box<DietRoutineSchedule> get dietRoutineSchedulesBox =>
      Hive.box<DietRoutineSchedule>(_dietRoutineSchedulesBoxName);

  /// Compat: mesma API das telas — **agora retorna Box<T> corretamente**
  Box<T> getBox<T>(String name) {
    switch (name) {
      case _userProfileBoxName:
        return userProfileBox as Box<T>;

      case _exercisesBoxName:
        return exercisesBox as Box<T>;
      case _workoutSessionsBoxName:
        return workoutSessionsBox as Box<T>;
      case _workoutDaysBoxName:
        return workoutDaysBox as Box<T>;
      case _workoutBlocksBoxName:
        return workoutBlocksBox as Box<T>;
      case _workoutRoutinesBoxName:
        return workoutRoutinesBox as Box<T>;
      case _workoutRoutineSchedulesBoxName:
      case _routineSchedulesAlias: // aceita 'routine_schedules'
        return workoutRoutineSchedulesBox as Box<T>;

      case _workoutSetEntriesBoxName:
        return workoutSetEntriesBox as Box<T>;
      case _workoutSessionLogsBoxName:
        return workoutSessionLogsBox as Box<T>;

      case _mealsBoxName:
        return mealsBox as Box<T>;
      case _mealEntriesBoxName:
        return mealEntriesBox as Box<T>;
      case _weightEntriesBoxName:
        return weightEntriesBox as Box<T>;

      case _dietDaysBoxName:
        return dietDaysBox as Box<T>;
      case _dietBlocksBoxName:
        return dietBlocksBox as Box<T>;
      case _dietRoutinesBoxName:
        return dietRoutinesBox as Box<T>;
      case _dietDayPlansBoxName:
        return dietDayPlansBox as Box<T>;
      case _dietDayMealPlanItemsBoxName:
        return dietDayMealPlanItemsBox as Box<T>;
      case _dietRoutineSchedulesBoxName:
        return dietRoutineSchedulesBox as Box<T>;

      default:
        throw ArgumentError('Box desconhecida: $name');
    }
  }

  // Perfil
  UserProfile getUserProfile() {
    if (userProfileBox.isEmpty) {
      final p = UserProfile(
        name: '',
        selectedLlm: 'gemini',
        geminiApiKey: '',
        gptApiKey: '',
      );
      userProfileBox.put('profile', p);
      return p;
    }
    return userProfileBox.values.first;
  }

  void saveUserProfile(UserProfile p) {
    userProfileBox.put('profile', p);
  }
}

// lib/core/services/hive_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// MODELS com adapters gerados
import 'package:fitapp/core/models/user_profile.dart';
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/workout_routine.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';
import 'package:fitapp/core/models/workout_session_log.dart';
import 'package:fitapp/core/models/workout_set_entry.dart';

import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/meal_entry.dart';

import 'package:fitapp/core/models/weight_entry.dart';

import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';

class HiveService {
  // Boxes tipadas
  late Box<UserProfile> userProfileBox;

  late Box<Exercise> exercisesBox;
  late Box<WorkoutSession> workoutSessionsBox;
  late Box<WorkoutDay> workoutDaysBox;
  late Box<WorkoutRoutine> workoutRoutinesBox;
  late Box<WorkoutBlock> workoutBlocksBox;
  late Box<WorkoutRoutineSchedule> routineSchedulesBox;
  late Box<WorkoutSessionLog> workoutSessionLogsBox;
  late Box<WorkoutSetEntry> workoutSetEntriesBox;

  late Box<Meal> mealsBox;
  late Box<MealEntry> mealEntriesBox;

  late Box<WeightEntry> weightEntriesBox;

  late Box<DietDay> dietDaysBox;
  late Box<DietRoutine> dietRoutinesBox;
  late Box<DietBlock> dietBlocksBox;
  late Box<DietDayPlan> dietDayPlansBox;
  late Box<DietDayMealPlanItem> dietDayMealPlanItemsBox;

  late Box appPrefsBox;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // registra adapters apenas se ainda não estiverem registrados
    void _reg(int id, TypeAdapter adapter) {
      if (!Hive.isAdapterRegistered(id)) {
        Hive.registerAdapter(adapter);
      }
    }

    _reg(0,  UserProfileAdapter());
    _reg(1,  ExerciseAdapter());
    _reg(11, WorkoutSessionAdapter());
    _reg(12, WorkoutDayAdapter());
    _reg(10, WorkoutRoutineAdapter());
    _reg(41, WorkoutBlockAdapter());
    _reg(43, WorkoutRoutineScheduleAdapter());
    _reg(26, WorkoutSessionLogAdapter());
    _reg(25, WorkoutSetEntryAdapter());

    _reg(20, MealAdapter());
    _reg(21, MealEntryAdapter());

    _reg(22, WeightEntryAdapter());

    _reg(23, DietDayAdapter());
    _reg(24, DietRoutineAdapter());
    _reg(42, DietBlockAdapter());
    _reg(28, DietDayPlanAdapter());
    _reg(29, DietDayMealPlanItemAdapter());

    // abre todas as boxes usadas no app
    userProfileBox        = await Hive.openBox<UserProfile>('user_profile');

    exercisesBox          = await Hive.openBox<Exercise>('exercises');
    workoutSessionsBox    = await Hive.openBox<WorkoutSession>('workout_sessions');
    workoutDaysBox        = await Hive.openBox<WorkoutDay>('workout_days');
    workoutRoutinesBox    = await Hive.openBox<WorkoutRoutine>('workout_routines');
    workoutBlocksBox      = await Hive.openBox<WorkoutBlock>('workout_blocks');
    routineSchedulesBox   = await Hive.openBox<WorkoutRoutineSchedule>('routine_schedules');

    workoutSessionLogsBox = await Hive.openBox<WorkoutSessionLog>('workout_session_logs');
    workoutSetEntriesBox  = await Hive.openBox<WorkoutSetEntry>('workout_set_entries');

    mealsBox              = await Hive.openBox<Meal>('meals');
    mealEntriesBox        = await Hive.openBox<MealEntry>('meal_entries');

    weightEntriesBox      = await Hive.openBox<WeightEntry>('weight_entries');

    dietDaysBox           = await Hive.openBox<DietDay>('diet_days');
    dietRoutinesBox       = await Hive.openBox<DietRoutine>('diet_routines');
    dietBlocksBox         = await Hive.openBox<DietBlock>('diet_blocks');
    dietDayPlansBox       = await Hive.openBox<DietDayPlan>('diet_day_plans');
    dietDayMealPlanItemsBox =
        await Hive.openBox<DietDayMealPlanItem>('diet_day_meal_plan_items');

    appPrefsBox           = await Hive.openBox('app_prefs');

    await _ensureDefaultProfile();

    _initialized = true;
  }

  // ---- Helpers públicos ----

  /// Retorna uma box já aberta pelo nome (tipada).
  Box<T> getBox<T>(String name) {
    if (!Hive.isBoxOpen(name)) {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<T>(name);
    }

  /// Lê (ou cria) o perfil padrão
  UserProfile getUserProfile() {
    final existing = userProfileBox.get('profile');
    if (existing is UserProfile) return existing;
    final p = UserProfile();
    userProfileBox.put('profile', p);
    return p;
  }

  /// Atualiza/salva o perfil padrão
  Future<void> saveUserProfile(UserProfile profile) async {
    if (profile.isInBox) {
      await profile.save();
    } else {
      await userProfileBox.put('profile', profile);
    }
  }

  // ---- Privados ----

  Future<void> _ensureDefaultProfile() async {
    if (!userProfileBox.containsKey('profile')) {
      await userProfileBox.put('profile', UserProfile());
    }
  }
}

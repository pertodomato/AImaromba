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
  // Nomes de boxes (evita typos)
  static const _bxUserProfile = 'user_profile';

  static const _bxExercises = 'exercises';
  static const _bxWorkoutSessions = 'workout_sessions';
  static const _bxWorkoutDays = 'workout_days';
  static const _bxWorkoutRoutines = 'workout_routines';
  static const _bxWorkoutBlocks = 'workout_blocks';
  static const _bxRoutineSchedules = 'routine_schedules';
  static const _bxWorkoutSessionLogs = 'workout_session_logs';
  static const _bxWorkoutSetEntries = 'workout_set_entries';

  static const _bxMeals = 'meals';
  static const _bxMealEntries = 'meal_entries';

  static const _bxWeightEntries = 'weight_entries';

  static const _bxDietDays = 'diet_days';
  static const _bxDietRoutines = 'diet_routines';
  static const _bxDietBlocks = 'diet_blocks';
  static const _bxDietDayPlans = 'diet_day_plans';
  static const _bxDietDayMealPlanItems = 'diet_day_meal_plan_items';

  static const _bxAppPrefs = 'app_prefs';

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

  late Box<dynamic> appPrefsBox;

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

    // === IDs estáveis (não alterar após dados em produção) ===
    _reg(0, UserProfileAdapter);

    _reg(1, ExerciseAdapter);
    _reg(10, WorkoutRoutineAdapter);
    _reg(11, WorkoutSessionAdapter);
    _reg(12, WorkoutDayAdapter);
    _reg(25, WorkoutSetEntryAdapter);
    _reg(26, WorkoutSessionLogAdapter);
    _reg(41, WorkoutBlockAdapter);
    _reg(43, WorkoutRoutineScheduleAdapter);

    _reg(20, MealAdapter);
    _reg(21, MealEntryAdapter);

    _reg(22, WeightEntryAdapter);

    _reg(23, DietDayAdapter);
    _reg(24, DietRoutineAdapter);
    _reg(28, DietDayPlanAdapter);
    _reg(29, DietDayMealPlanItemAdapter);
    _reg(42, DietBlockAdapter);

    // abre todas as boxes usadas no app
    userProfileBox = await Hive.openBox<UserProfile>(_bxUserProfile);

    exercisesBox = await Hive.openBox<Exercise>(_bxExercises);
    workoutSessionsBox =
        await Hive.openBox<WorkoutSession>(_bxWorkoutSessions);
    workoutDaysBox = await Hive.openBox<WorkoutDay>(_bxWorkoutDays);
    workoutRoutinesBox =
        await Hive.openBox<WorkoutRoutine>(_bxWorkoutRoutines);
    workoutBlocksBox = await Hive.openBox<WorkoutBlock>(_bxWorkoutBlocks);
    routineSchedulesBox =
        await Hive.openBox<WorkoutRoutineSchedule>(_bxRoutineSchedules);

    workoutSessionLogsBox =
        await Hive.openBox<WorkoutSessionLog>(_bxWorkoutSessionLogs);
    workoutSetEntriesBox =
        await Hive.openBox<WorkoutSetEntry>(_bxWorkoutSetEntries);

    mealsBox = await Hive.openBox<Meal>(_bxMeals);
    mealEntriesBox = await Hive.openBox<MealEntry>(_bxMealEntries);

    weightEntriesBox = await Hive.openBox<WeightEntry>(_bxWeightEntries);

    dietDaysBox = await Hive.openBox<DietDay>(_bxDietDays);
    dietRoutinesBox = await Hive.openBox<DietRoutine>(_bxDietRoutines);
    dietBlocksBox = await Hive.openBox<DietBlock>(_bxDietBlocks);
    dietDayPlansBox = await Hive.openBox<DietDayPlan>(_bxDietDayPlans);
    dietDayMealPlanItemsBox =
        await Hive.openBox<DietDayMealPlanItem>(_bxDietDayMealPlanItems);

    appPrefsBox = await Hive.openBox<dynamic>(_bxAppPrefs);

    await _ensureDefaultProfile();

    _initialized = true;

    if (kDebugMode) {
      for (final name in [
        _bxUserProfile,
        _bxExercises,
        _bxWorkoutSessions,
        _bxWorkoutDays,
        _bxWorkoutRoutines,
        _bxWorkoutBlocks,
        _bxRoutineSchedules,
        _bxWorkoutSessionLogs,
        _bxWorkoutSetEntries,
        _bxMeals,
        _bxMealEntries,
        _bxWeightEntries,
        _bxDietDays,
        _bxDietRoutines,
        _bxDietBlocks,
        _bxDietDayPlans,
        _bxDietDayMealPlanItems,
        _bxAppPrefs,
      ]) {
        // ignore: avoid_print
        print('Got object store box in database $name.');
      }
    }
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

// Pequena extensão auxiliar para registrar adapters com sintaxe curta
extension on TypeAdapter {
  static void call(TypeAdapter adapter) {
    // no-op, apenas permite _reg(id, Adapter()) ou _reg(id, Adapter);
  }
}

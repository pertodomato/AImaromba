// lib/core/services/hive_service.dart
import 'package:hive_flutter/hive_flutter.dart';

// Models base já existentes
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/workout_set_entry.dart';
import 'package:fitapp/core/models/workout_session_log.dart';

// Novos modelos (treino)
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';

// Novos modelos (dieta)
import 'package:fitapp/core/models/diet_block.dart';
// Se for usar os planos detalhados do dia de dieta:
import 'package:fitapp/core/models/diet_day_plan.dart';
import 'package:fitapp/core/models/diet_day_meal_plan_item.dart';

class HiveService {
  Future<void> init() async {
    await Hive.initFlutter();

    // ----------------------
    // Registros de Adapters
    // ----------------------
    // Perfil/usuário & bases
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(ExerciseAdapter());
    Hive.registerAdapter(WorkoutSessionAdapter());
    Hive.registerAdapter(WorkoutDayAdapter());
    Hive.registerAdapter(WorkoutRoutineAdapter());

    // Treino – novos
    Hive.registerAdapter(WorkoutBlockAdapter());
    Hive.registerAdapter(WorkoutRoutineScheduleAdapter());

    // Dieta – já existentes
    Hive.registerAdapter(MealAdapter());
    Hive.registerAdapter(MealEntryAdapter());
    Hive.registerAdapter(WeightEntryAdapter());
    Hive.registerAdapter(DietDayAdapter());
    Hive.registerAdapter(DietRoutineAdapter());

    // Dieta – novos
    Hive.registerAdapter(DietBlockAdapter());

    // Logs/sets
    Hive.registerAdapter(WorkoutSetEntryAdapter());
    Hive.registerAdapter(WorkoutSessionLogAdapter());

    // Planos diários detalhados de dieta (se usar)
    Hive.registerAdapter(DietDayPlanAdapter());
    Hive.registerAdapter(DietDayMealPlanItemAdapter());

    // -----------
    // Abertura de Boxes
    // -----------
    // Perfil
    await Hive.openBox<UserProfile>('user_profile');

    // Treino
    await Hive.openBox<Exercise>('exercises');
    await Hive.openBox<WorkoutSession>('workout_sessions');
    await Hive.openBox<WorkoutDay>('workout_days');
    await Hive.openBox<WorkoutRoutine>('workout_routines');
    await Hive.openBox<WorkoutBlock>('workout_blocks'); // novo
    await Hive.openBox<WorkoutRoutineSchedule>('routine_schedules'); // novo

    // Dieta
    await Hive.openBox<Meal>('meals');
    await Hive.openBox<MealEntry>('meal_entries');
    await Hive.openBox<WeightEntry>('weight_entries');
    await Hive.openBox<DietDay>('diet_days');
    await Hive.openBox<DietRoutine>('diet_routines');
    await Hive.openBox<DietBlock>('diet_blocks'); // novo

    // Dieta – planos detalhados (se usar)
    await Hive.openBox<DietDayPlan>('diet_day_plans');
    await Hive.openBox<DietDayMealPlanItem>('diet_day_meal_plan_items');
  }

  Box<T> getBox<T>(String boxName) => Hive.box<T>(boxName);

  // Perfil
  UserProfile getUserProfile() {
    final box = getBox<UserProfile>('user_profile');
    if (box.isEmpty) {
      // Caso seu UserProfile exija campos obrigatórios no construtor,
      // ajuste aqui. Se não, o construtor vazio está OK.
      box.add(UserProfile());
    }
    return box.getAt(0)!;
  }

  void saveUserProfile(UserProfile profile) {
    final box = getBox<UserProfile>('user_profile');
    if (box.isEmpty) {
      box.add(profile);
    } else {
      box.putAt(0, profile);
    }
  }
}

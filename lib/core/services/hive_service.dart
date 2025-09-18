import 'package:hive_flutter/hive_flutter.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/models/workout_set_entry.dart';
import 'package:fitapp/core/models/workout_session_log.dart';

class HiveService {
  Future<void> init() async {
    await Hive.initFlutter();

    // Adapters
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(ExerciseAdapter());
    Hive.registerAdapter(WorkoutSessionAdapter());
    Hive.registerAdapter(WorkoutDayAdapter());
    Hive.registerAdapter(WorkoutRoutineAdapter());
    Hive.registerAdapter(MealAdapter());
    Hive.registerAdapter(MealEntryAdapter());
    Hive.registerAdapter(WeightEntryAdapter());
    Hive.registerAdapter(DietDayAdapter());
    Hive.registerAdapter(DietRoutineAdapter());
    Hive.registerAdapter(WorkoutSetEntryAdapter());
    Hive.registerAdapter(WorkoutSessionLogAdapter());

    // Boxes
    await Hive.openBox<UserProfile>('user_profile');
    await Hive.openBox<Exercise>('exercises');
    await Hive.openBox<WorkoutSession>('workout_sessions');
    await Hive.openBox<WorkoutDay>('workout_days');
    await Hive.openBox<WorkoutRoutine>('workout_routines');
    await Hive.openBox<Meal>('meals');
    await Hive.openBox<MealEntry>('meal_entries');
    await Hive.openBox<WeightEntry>('weight_entries');
    await Hive.openBox<DietDay>('diet_days');
    await Hive.openBox<DietRoutine>('diet_routines');
    await Hive.openBox<WorkoutSetEntry>('workout_set_entries');
    await Hive.openBox<WorkoutSessionLog>('workout_session_logs');
  }

  Box<T> getBox<T>(String boxName) => Hive.box<T>(boxName);

  // Perfil
  UserProfile getUserProfile() {
    final box = getBox<UserProfile>('user_profile');
    if (box.isEmpty) {
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/services/food_repository.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/features/0_home/presentation/pages/home_screen.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveService hiveService;

  Future<void> seedRoutine({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final exercisesBox = hiveService.getBox<Exercise>('exercises');
    final sessionsBox = hiveService.getBox<WorkoutSession>('workout_sessions');
    final daysBox = hiveService.getBox<WorkoutDay>('workout_days');
    final routinesBox = hiveService.getBox<WorkoutRoutine>('workout_routines');
    final schedulesBox = hiveService.getBox<WorkoutRoutineSchedule>('routine_schedules');
    final mealsBox = hiveService.getBox<Meal>('meals');
    final mealEntriesBox = hiveService.getBox<MealEntry>('meal_entries');
    final weightsBox = hiveService.getBox<WeightEntry>('weight_entries');
    final profileBox = hiveService.getBox<UserProfile>('user_profile');

    exercisesBox.clear();
    sessionsBox.clear();
    daysBox.clear();
    routinesBox.clear();
    schedulesBox.clear();
    mealsBox.clear();
    mealEntriesBox.clear();
    weightsBox.clear();
    profileBox.put('profile', UserProfile(dailyKcalGoal: 2200));

    final exercise = Exercise(
      id: 'ex-1',
      name: 'Supino',
      description: 'Supino reto',
      primaryMuscles: const ['peito'],
      secondaryMuscles: const ['tríceps'],
      relevantMetrics: const ['Peso', 'Repetições'],
    );
    await exercisesBox.add(exercise);

    final session = WorkoutSession(
      id: 'sess-1',
      name: 'Peito A',
      description: 'Treino de peito',
      exercises: HiveList(exercisesBox)..add(exercise),
    );
    await sessionsBox.add(session);

    final day = WorkoutDay(
      id: 'day-1',
      name: 'Dia A',
      description: 'Primeiro dia',
      sessions: HiveList(sessionsBox)..add(session),
    );
    await daysBox.add(day);

    final routine = WorkoutRoutine(
      id: 'routine-1',
      name: 'Plano Verão',
      description: 'Rotina de testes',
      startDate: start,
      repetitionSchema: 'Semanal',
      days: HiveList(daysBox)..add(day),
    );
    await routinesBox.add(routine);

    final schedule = WorkoutRoutineSchedule(
      routineSlug: toSlug(routine.name),
      blockSequence: const ['dia_a'],
      repetitionSchema: 'Semanal',
      endDate: endDate,
    );
    await schedulesBox.add(schedule);
  }

  void registerTestAdapters() {
    if (!Hive.isAdapterRegistered(UserProfileAdapter().typeId)) {
      Hive.registerAdapter(UserProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(ExerciseAdapter().typeId)) {
      Hive.registerAdapter(ExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(WorkoutSessionAdapter().typeId)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(WorkoutDayAdapter().typeId)) {
      Hive.registerAdapter(WorkoutDayAdapter());
    }
    if (!Hive.isAdapterRegistered(WorkoutRoutineAdapter().typeId)) {
      Hive.registerAdapter(WorkoutRoutineAdapter());
    }
    if (!Hive.isAdapterRegistered(WorkoutRoutineScheduleAdapter().typeId)) {
      Hive.registerAdapter(WorkoutRoutineScheduleAdapter());
    }
    if (!Hive.isAdapterRegistered(MealAdapter().typeId)) {
      Hive.registerAdapter(MealAdapter());
    }
    if (!Hive.isAdapterRegistered(MealEntryAdapter().typeId)) {
      Hive.registerAdapter(MealEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(WeightEntryAdapter().typeId)) {
      Hive.registerAdapter(WeightEntryAdapter());
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('home_screen_test');
    Hive.init(tempDir.path);
    registerTestAdapters();
    await Hive.openBox<UserProfile>('user_profile');
    await Hive.openBox<Exercise>('exercises');
    await Hive.openBox<WorkoutSession>('workout_sessions');
    await Hive.openBox<WorkoutDay>('workout_days');
    await Hive.openBox<WorkoutRoutine>('workout_routines');
    await Hive.openBox<WorkoutRoutineSchedule>('workout_routine_schedules');
    await Hive.openBox<Meal>('meals');
    await Hive.openBox<MealEntry>('meal_entries');
    await Hive.openBox<WeightEntry>('weight_entries');
    hiveService = HiveService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('HomeScreen hides workouts once the plan end date has passed', (tester) async {
    await seedRoutine(endDate: DateTime.now().subtract(const Duration(days: 1)));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HiveService>.value(value: hiveService),
          Provider<FoodRepository>.value(value: FoodRepository()),
          Provider<LLMService>.value(value: LLMService()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Plano concluído'), findsOneWidget);
    expect(find.text('Criar novo plano'), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
  });
}


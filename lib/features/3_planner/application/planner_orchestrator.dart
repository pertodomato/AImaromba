// lib/features/3_planner/application/planner_orchestrator.dart
import 'dart:math';
import 'package:fitapp/features/3_planner/infrastructure/llm/llm_client_impl.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_workout_repo.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_diet_repo.dart';
import 'package:fitapp/core/utils/muscle_validation.dart';

class PlannerOrchestrator {
  final LLMClientImpl llm;
  final HiveWorkoutRepo workoutRepo;
  final HiveDietRepo dietRepo;

  PlannerOrchestrator({
    required this.llm,
    required this.workoutRepo,
    required this.dietRepo,
  });

  // ------------------ TREINO ------------------

  Future<void> buildWorkoutFromQA({
    required Map<String, Object?> userProfile,
    required List<Map<String, String>> userAnswers,
  }) async {
    // 1) Routine -> Blocks
    final routineJson = await llm.getWorkoutRoutine(
      userProfile: userProfile,
      userAnswers: userAnswers,
      existingBlocks: [], // liste os existentes se quiser sugerir reuso
    );

    final routineName = routineJson['routine']['name'] as String;
    final routineDesc = routineJson['routine']['description'] as String;
    final repetitionSchema = routineJson['routine']['repetition_schema'] as String;
    final blockPlaceholders = List<String>.from(routineJson['routine']['block_sequence_placeholders']);

    final routine = workoutRepo.upsertRoutine(name: routineName, description: routineDesc);

    // 2) Criar blocks (placeholders)
    final blocksCreated = <String, dynamic>{}; // placeholder_id -> block entity
    for (final b in (routineJson['blocks_to_create'] as List)) {
      final ph = b['placeholder_id'] as String;
      final blockName = b['name'] as String;
      final blockDesc = b['description'] as String;

      // 2.1) Block -> Days
      final blockStruct = await llm.getWorkoutBlockStructure(
        blockPlaceholder: {'placeholder_id': ph, 'name': blockName, 'description': blockDesc},
        existingDays: [],
      );

      final days = <dynamic>[];
      for (final dayMeta in (blockStruct['days_to_create'] as List)) {
        final isRest = dayMeta['is_rest'] == true;

        if (isRest) {
          final day = workoutRepo.upsertDay(
            name: dayMeta['name'],
            description: dayMeta['description'],
            isRest: true,
            sessions: const [],
          );
          days.add(day);
          continue;
        }

        // 3) Day -> Sessions + Exercises
        final daySessions = await llm.getWorkoutDaySessions(
          dayPlaceholder: {
            'day_id': dayMeta['placeholder_id'],
            'name': dayMeta['name'],
            'description': dayMeta['description'],
          },
          existingSessions: [],
          existingExercises: [], // se quiser passar catálogo
          validMuscles: kValidGroupIds.toList(),
        );

        final sessions = <dynamic>[];
        for (final sess in (daySessions['sessions_to_create'] as List)) {
          final newExercises = <dynamic>[];
          for (final ex in (sess['exercises_to_create'] as List)) {
            final e = workoutRepo.upsertExercise(
              name: ex['name'],
              description: ex['description'],
              primary: List<String>.from(ex['primary_muscles']),
              secondary: List<String>.from(ex['secondary_muscles']),
              metrics: List<String>.from(ex['relevant_metrics']),
            );
            newExercises.add(e);
          }
          final s = workoutRepo.upsertSession(
            name: sess['name'],
            description: sess['description'],
            exercises: List<dynamic>.from(newExercises).cast(), // já inclui reuso se você quiser
          );
          sessions.add(s);
        }

        final day = workoutRepo.upsertDay(
          name: dayMeta['name'],
          description: dayMeta['description'],
          isRest: false,
          sessions: List<dynamic>.from(sessions).cast(),
        );

        days.add(day);
      }

      // 4) Persist block com days ordenados (1–15)
      final block = workoutRepo.upsertBlock(
        name: blockName,
        description: blockDesc,
        daysOrdered: List<dynamic>.from(days).cast(),
      );
      blocksCreated[ph] = block;
    }

    // 5) Persist schedule da rotina
    final sequence = blockPlaceholders.map((ph) => blocksCreated[ph]).where((e) => e != null).cast().toList();
    workoutRepo.upsertRoutineSchedule(
      routineSlug: routine.name.toLowerCase().replaceAll(' ', '_'),
      repetitionSchema: repetitionSchema,
      sequence: sequence,
    );
  }

  // ------------------ NUTRIÇÃO ------------------

  Future<void> buildDietFromQA({
    required Map<String, Object?> userProfile,
    required String userGoal,
    required List<Map<String, String>> userAnswers,
    required List<String> foodPrefs,
    required Map<String, num> defaultDayTargets, // ex.: {"calories": 2200, "protein_g": 160, ...}
  }) async {
    // 1) DietRoutine -> DietBlocks
    final routineJson = await llm.getDietRoutine(
      userProfile: userProfile,
      userAnswers: userAnswers,
      existingDietBlocks: [],
    );

    final rName = routineJson['diet_routine']['name'] as String;
    final rDesc = routineJson['diet_routine']['description'] as String;
    final repetition = routineJson['diet_routine']['repetition_schema'] as String;
    final blockPHs = List<String>.from(routineJson['diet_routine']['block_sequence_placeholders']);

    final blocksCreated = <String, dynamic>{};

    for (final b in (routineJson['blocks_to_create'] as List)) {
      final ph = b['placeholder_id'] as String;
      final bName = b['name'] as String;
      final bDesc = b['description'] as String;

      // 2) Block -> DietDays
      final blockStruct = await llm.getDietBlockStructure(
        dietBlockPlaceholder: {'placeholder_id': ph, 'name': bName, 'description': bDesc},
        existingDietDays: [],
        userFoodPrefs: foodPrefs,
      );

      final days = <dynamic>[];

      for (final d in (blockStruct['days_to_create'] as List)) {
        // 3) Para criar a estrutura base do dia, você pode reusar refeições catálogo
        // Aqui simplifico, criando o Day com refeição placeholders (você pode enriquecer com seu catálogo real)
        final baseMeals = <Meal>[];
        // Ex.: criar (ou reusar) uma refeição genérica por nome
        baseMeals.add(dietRepo.upsertMeal(
          name: "Café Proteico Aveia",
          description: "Ovos/claras, aveia e fruta.",
          kcalPer100: 130, pPer100: 10, cPer100: 15, fPer100: 3.5,
        ));
        baseMeals.add(dietRepo.upsertMeal(
          name: "Almoço Frango Arroz Feijão",
          description: "Frango magro, arroz e feijão; salada.",
          kcalPer100: 135, pPer100: 11, cPer100: 17, fPer100: 3,
        ));
        baseMeals.add(dietRepo.upsertMeal(
          name: "Jantar Peixe + Batata + Legumes",
          description: "Peixe assado, batata, legumes.",
          kcalPer100: 120, pPer100: 12, cPer100: 12, fPer100: 2.5,
        ));

        final dayEntity = dietRepo.upsertDietDay(
          name: d['name'],
          description: d['description'],
          structure: baseMeals,
        );
        days.add(dayEntity);

        // 4) Day Plan com quantidades (via LLM)
        final plan = await llm.getDietDayPlan(
          userProfile: userProfile,
          userGoal: userGoal,
          userFoodPrefs: foodPrefs,
          dietDay: {'diet_day_id': d['placeholder_id'], 'name': d['name'], 'description': d['description']},
          existingMealsSummary: baseMeals.map((m) => {
            'name': m.name,
            'calories_per_100g': m.caloriesPer100g,
            'protein_per_100g': m.proteinPer100g,
            'carbs_per_100g': m.carbsPer100g,
            'fat_per_100g': m.fatPer100g,
          }).toList(),
          dayTargets: defaultDayTargets,
        );

        // Se você já tem DietDayPlan/Items, persista aqui usando planBox/planItemBox
        // (omiti para manter o exemplo focado no fluxo)
      }

      final block = dietRepo.upsertDietBlock(
        name: bName,
        description: bDesc,
        daysOrdered: List<dynamic>.from(days).cast(),
      );
      blocksCreated[ph] = block;
    }

    // 5) DietRoutine final
    final sequence = blockPHs.map((ph) => blocksCreated[ph]).where((e) => e != null).cast().toList();
    dietRepo.upsertDietRoutine(
      name: rName,
      description: rDesc,
      repetitionSchema: repetition,
      sequence: sequence,
    );
  }
}

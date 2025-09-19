// lib/features/3_planner/application/planner_orchestrator.dart
import 'dart:async';
import 'dart:convert';

import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_day.dart';
import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/exercise.dart';

import 'package:fitapp/features/3_planner/infrastructure/llm/llm_client_impl.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_workout_repo.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_diet_repo.dart';

import 'package:fitapp/core/utils/muscle_validation.dart';

class ProgressEvent {
  final String message;
  final double progress; // 0.0..1.0
  const ProgressEvent(this.message, this.progress);
}

class PlannerOrchestrator {
  final LLMClientImpl llm;
  final HiveWorkoutRepo workoutRepo;
  final HiveDietRepo dietRepo;

  PlannerOrchestrator({
    required this.llm,
    required this.workoutRepo,
    required this.dietRepo,
  });

  // ------------------ Perguntas (1 etapa) ------------------
  Future<List<Map<String, String>>> generateQuestions({
    required Map<String, Object?> userProfile,
    required String userGoal,
  }) async {
    final Map<String, dynamic> json = await llm.generateFromAsset(
      'assets/prompts/planner_get_questions.txt',
      vars: {
        'user_profile': jsonEncode(userProfile),
        'user_goal': userGoal,
      },
    );
    final list = (json['questions'] as List?) ?? const [];
    return list
        .map((e) => {
              'id': e['id']?.toString() ?? '',
              'text': e['text']?.toString() ?? '',
            })
        .toList();
  }

  // ------------------ Resumos (workout + nutrition) ------------------
  Future<Map<String, String>> generateSummaries({
    required Map<String, Object?> userProfile,
    required String userGoal,
    required Map<String, String> answers,
  }) async {
    final Map<String, dynamic> json = await llm.generateFromAsset(
      'assets/prompts/planner_get_summary.txt',
      vars: {
        'user_profile': jsonEncode(userProfile),
        'user_goal': userGoal,
        'user_answers': jsonEncode(
          answers.entries
              .map((e) => {'id': e.key, 'pergunta': e.key, 'resposta': e.value})
              .toList(),
        ),
      },
    );
    return {
      'workout_summary': (json['workout_summary'] ?? '').toString(),
      'nutrition_summary': (json['nutrition_summary'] ?? '').toString(),
    };
  }

  // ------------------ TREINO: constrói tudo com progresso ------------------
  Stream<ProgressEvent> buildWorkoutPlan({
    required Map<String, Object?> userProfile,
    required Map<String, String> answers,
  }) async* {
    // 0) Preparação
    yield const ProgressEvent('Planejando rotina de treino...', 0.05);

    // 1) Routine -> Blocks
    final routineJson = await llm.getWorkoutRoutine(
      userProfile: userProfile,
      userAnswers: answers.entries
          .map((e) => {'id': e.key, 'pergunta': e.key, 'resposta': e.value})
          .toList(),
      existingBlocks: const [],
    );
    yield const ProgressEvent('Rotina definida. Gerando blocos...', 0.15);

    final routineName = routineJson['routine']['name'] as String;
    final routineDesc = routineJson['routine']['description'] as String;
    final repetitionSchema = routineJson['routine']['repetition_schema'] as String;
    final blockPlaceholders = List<String>.from(
      routineJson['routine']['block_sequence_placeholders'] ?? const [],
    );

    // cria/garante a rotina
    final routine = workoutRepo.upsertRoutine(name: routineName, description: routineDesc);

    // 2) Criar blocks (placeholders)
    final Map<String, WorkoutBlock> blocksCreated = {};
    final blocks = (routineJson['blocks_to_create'] as List?) ?? const [];
    int doneBlocks = 0;

    for (final b in blocks) {
      final ph = b['placeholder_id'] as String;
      final blockName = b['name'] as String;
      final blockDesc = b['description'] as String;

      yield ProgressEvent(
        'Detalhando bloco "$blockName"...',
        0.2 + 0.4 * (doneBlocks / (blocks.isEmpty ? 1 : blocks.length)),
      );

      // 2.1) Block -> Days (1..15)
      final blockStruct = await llm.getWorkoutBlockStructure(
        blockPlaceholder: {'placeholder_id': ph, 'name': blockName, 'description': blockDesc},
        existingDays: const [],
      );

      final List<WorkoutDay> daysOut = [];
      final daysToCreate = (blockStruct['days_to_create'] as List?) ?? const [];

      for (final dayMeta in daysToCreate) {
        final bool isRest = dayMeta['is_rest'] == true;

        if (isRest) {
          final dayRest = workoutRepo.upsertDay(
            name: dayMeta['name'] as String,
            description: (dayMeta['description'] as String?) ?? 'Descanso',
            isRest: true,
            sessions: const <WorkoutSession>[],
          );
          daysOut.add(dayRest);
          continue;
        }

        // 3) Day -> Sessions + Exercises
        final daySessions = await llm.getWorkoutDaySessions(
          dayPlaceholder: {
            'day_id': dayMeta['placeholder_id'],
            'name': dayMeta['name'],
            'description': dayMeta['description'],
          }.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
          existingSessions: const [],
          existingExercises: const [],
          validMuscles: kValidGroupIds.toList(),
        );

        final List<WorkoutSession> sessionsList = [];
        final sessionsToCreate = (daySessions['sessions_to_create'] as List?) ?? const [];

        for (final sess in sessionsToCreate) {
          final List<Exercise> newExercises = [];
          final exercises = (sess['exercises_to_create'] as List?) ?? const [];
          for (final ex in exercises) {
            final exercise = workoutRepo.upsertExercise(
              name: ex['name'] as String,
              description: (ex['description'] as String?) ?? '',
              primary: List<String>.from(ex['primary_muscles'] ?? const []),
              secondary: List<String>.from(ex['secondary_muscles'] ?? const []),
              metrics: List<String>.from(ex['relevant_metrics'] ?? const []),
            );
            newExercises.add(exercise);
          }
          final session = workoutRepo.upsertSession(
            name: (sess['name'] ?? 'Sessão').toString(),
            description: (sess['description'] ?? '').toString(),
            exercises: newExercises,
          );
          sessionsList.add(session);
        }

        final dayEntity = workoutRepo.upsertDay(
          name: (dayMeta['name'] ?? 'Dia').toString(),
          description: (dayMeta['description'] ?? '').toString(),
          isRest: false,
          sessions: sessionsList,
        );
        daysOut.add(dayEntity);
      }

      final block = workoutRepo.upsertBlock(
        name: blockName,
        description: blockDesc,
        daysOrdered: daysOut,
      );
      blocksCreated[ph] = block;
      doneBlocks++;
    }

    // 3) Persist schedule da rotina
    final List<WorkoutBlock> sequence = blockPlaceholders
        .map((ph) => blocksCreated[ph])
        .where((e) => e != null)
        .cast<WorkoutBlock>()
        .toList();

    workoutRepo.upsertRoutineSchedule(
      routineSlug: routine.name.toLowerCase().replaceAll(' ', '_'),
      repetitionSchema: repetitionSchema,
      sequence: sequence, // já é List<WorkoutBlock>
    );

    yield const ProgressEvent('Treino concluído!', 1.0);
  }

  // ------------------ DIETA: constrói tudo com progresso ------------------
  Stream<ProgressEvent> buildDietPlan({
    required Map<String, Object?> userProfile,
    required Map<String, String> answers,
  }) async* {
    // Você pode derivar metas padrão do perfil/objetivo. Aqui simplifico:
    final Map<String, num> defaultDayTargets = <String, num>{
      'calories': 2200,
      'protein_g': 160,
      'carbs_g': 230,
      'fat_g': 70,
      'fiber_g': 28,
      'water_l': 2.7,
    };
    final userGoal = (answers['goal'] ?? answers['objetivo'] ?? '').toString();
    final List<String> foodPrefs = const <String>[]; // alimente de verdade se tiver

    yield const ProgressEvent('Planejando rotina de dieta...', 0.05);

    // 1) DietRoutine -> DietBlocks
    final routineJson = await llm.getDietRoutine(
      userProfile: userProfile,
      userAnswers: answers.entries
          .map((e) => {'id': e.key, 'pergunta': e.key, 'resposta': e.value})
          .toList(),
      existingDietBlocks: const [],
    );
    yield const ProgressEvent('Rotina de dieta definida. Gerando blocos...', 0.15);

    final rName = routineJson['diet_routine']['name'] as String;
    final rDesc = routineJson['diet_routine']['description'] as String;
    final repetition = routineJson['diet_routine']['repetition_schema'] as String;
    final blockPHs = List<String>.from(
      routineJson['diet_routine']['block_sequence_placeholders'] ?? const [],
    );

    final Map<String, DietBlock> blocksCreated = {};
    final blocks = (routineJson['blocks_to_create'] as List?) ?? const [];
    int doneBlocks = 0;

    for (final b in blocks) {
      final ph = b['placeholder_id'] as String;
      final bName = b['name'] as String;
      final bDesc = b['description'] as String;

      yield ProgressEvent(
        'Detalhando bloco de dieta "$bName"...',
        0.2 + 0.5 * (doneBlocks / (blocks.isEmpty ? 1 : blocks.length)),
      );

      // 2) Block -> DietDays
      final blockStruct = await llm.getDietBlockStructure(
        dietBlockPlaceholder: {'placeholder_id': ph, 'name': bName, 'description': bDesc},
        existingDietDays: const [],
        userFoodPrefs: foodPrefs,
      );

      final List<DietDay> days = [];
      final daysToCreate = (blockStruct['days_to_create'] as List?) ?? const [];

      for (final d in daysToCreate) {
        // Estrutura base do dia (catálogo simples para o exemplo)
        final List<Meal> baseMeals = <Meal>[
          dietRepo.upsertMeal(
            name: 'Café Proteico Aveia',
            description: 'Ovos/claras, aveia e fruta.',
            kcalPer100: 130,
            pPer100: 10,
            cPer100: 15,
            fPer100: 3.5,
          ),
          dietRepo.upsertMeal(
            name: 'Almoço Frango Arroz Feijão',
            description: 'Frango magro, arroz e feijão; salada.',
            kcalPer100: 135,
            pPer100: 11,
            cPer100: 17,
            fPer100: 3,
          ),
          dietRepo.upsertMeal(
            name: 'Jantar Peixe Batata Legumes',
            description: 'Peixe assado, batata e legumes.',
            kcalPer100: 120,
            pPer100: 12,
            cPer100: 12,
            fPer100: 2.5,
          ),
        ];

        final dayEntity = dietRepo.upsertDietDay(
          name: (d['name'] ?? 'Dia de Dieta').toString(),
          description: (d['description'] ?? '').toString(),
          structure: baseMeals,
        );
        days.add(dayEntity);

        // 3) Day Plan com quantidades (via LLM)
        await llm.getDietDayPlan(
          userProfile: userProfile,
          userGoal: userGoal,
          userFoodPrefs: foodPrefs,
          dietDay: {
            'diet_day_id': d['placeholder_id'],
            'name': d['name'],
            'description': d['description'],
          }.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
          existingMealsSummary: baseMeals
              .map((m) => {
                    'name': m.name,
                    'calories_per_100g': m.caloriesPer100g,
                    'protein_per_100g': m.proteinPer100g,
                    'carbs_per_100g': m.carbsPer100g,
                    'fat_per_100g': m.fatPer100g,
                  })
              .toList(),
          dayTargets: defaultDayTargets,
        );
      }

      final block = dietRepo.upsertDietBlock(
        name: bName,
        description: bDesc,
        daysOrdered: days,
      );
      blocksCreated[ph] = block;
      doneBlocks++;
    }

    // 4) DietRoutine final
    final List<DietBlock> sequence = blockPHs
        .map((ph) => blocksCreated[ph])
        .where((e) => e != null)
        .cast<DietBlock>()
        .toList();

    dietRepo.upsertDietRoutine(
      name: rName,
      description: rDesc,
      repetitionSchema: repetition,
      sequence: sequence, // já é List<DietBlock>
    );

    yield const ProgressEvent('Dieta concluída!', 1.0);
  }
}

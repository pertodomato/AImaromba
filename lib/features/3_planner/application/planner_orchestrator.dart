// lib/features/3_planner/application/planner_orchestrator.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fitapp/core/constants/diet_weight_goal.dart';
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
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

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

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static const int _defaultDurationDays = 180;

  DateTime _resolveRoutineEndDate({
    required DateTime startDate,
    Map<String, dynamic>? routineMeta,
    int? fallbackDays,
  }) {
    DateTime? explicitEnd;
    final rawEnd = routineMeta?['end_date'];
    if (rawEnd != null) {
      final candidate = DateTime.tryParse(rawEnd.toString());
      if (candidate != null) {
        explicitEnd = _dateOnly(candidate);
      }
    }

    int? durationDays;
    final rawDuration = routineMeta?['target_duration_days'] ??
        routineMeta?['duration_days'] ??
        routineMeta?['total_days'];
    if (rawDuration != null) {
      final parsed = int.tryParse(rawDuration.toString());
      if (parsed != null && parsed > 0) {
        durationDays = parsed;
      }
    }

    DateTime candidateEnd;
    if (explicitEnd != null) {
      candidateEnd = explicitEnd;
    } else if (durationDays != null) {
      candidateEnd = startDate.add(Duration(days: durationDays - 1));
    } else if (fallbackDays != null && fallbackDays > _defaultDurationDays) {
      candidateEnd = startDate.add(Duration(days: fallbackDays - 1));
    } else {
      candidateEnd = startDate.add(const Duration(days: _defaultDurationDays - 1));
    }

    if (candidateEnd.isBefore(startDate)) {
      return startDate;
    }
    return _dateOnly(candidateEnd);
  }

  // ------------------ Perguntas ------------------
  Future<List<Map<String, String>>> generateQuestions({
    required Map<String, Object?> userProfile,
    required String userGoal,
  }) async {
    // ignore: avoid_print
    print('== generateQuestions -> goal="$userGoal"');
    final Map<String, dynamic> json = await llm.generateFromAsset(
      'assets/prompts/planner_get_questions.txt',
      vars: {
        'user_profile': jsonEncode(userProfile),
        'user_goal': userGoal,
      },
    );
    final list = (json['questions'] as List?) ?? const [];
    // ignore: avoid_print
    print('.. questions received: ${list.length}');
    return list
        .map((e) => {
              'id': e['id']?.toString() ?? '',
              'text': e['text']?.toString() ?? '',
            })
        .toList();
  }

  // ------------------ Resumos ------------------
  Future<Map<String, String>> generateSummaries({
    required Map<String, Object?> userProfile,
    required String userGoal,
    required Map<String, String> answers,
  }) async {
    // ignore: avoid_print
    print('== generateSummaries');
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
    final out = {
      'workout_summary': (json['workout_summary'] ?? '').toString(),
      'nutrition_summary': (json['nutrition_summary'] ?? '').toString(),
    };
    // ignore: avoid_print
    print('.. summaries ready (workout:${out['workout_summary']!.isNotEmpty}, diet:${out['nutrition_summary']!.isNotEmpty})');
    return out;
  }

  // ------------------ TREINO: constrói tudo com progresso ------------------
  Stream<ProgressEvent> buildWorkoutPlan({
    required Map<String, Object?> userProfile,
    required Map<String, String> answers,
  }) async* {
    // ignore: avoid_print
    print('== buildWorkoutPlan (start)');
    yield const ProgressEvent('Planejando rotina de treino...', 0.05);

    final routineJson = await llm.getWorkoutRoutine(
      userProfile: userProfile,
      userAnswers: answers.entries
          .map((e) => {'id': e.key, 'pergunta': e.key, 'resposta': e.value})
          .toList(),
      existingBlocks: const [],
    );
    // ignore: avoid_print
    print('.. routineJson keys: ${routineJson.keys}');

    yield const ProgressEvent('Rotina definida. Gerando blocos...', 0.15);

    final routineName = (routineJson['routine']?['name'] ?? '').toString();
    final routineDesc = (routineJson['routine']?['description'] ?? '').toString();
    final repetitionSchema =
        (routineJson['routine']?['repetition_schema'] ?? 'Semanal').toString();
    final blockPlaceholders = List<String>.from(
      routineJson['routine']?['block_sequence_placeholders'] ?? const [],
    );

    // cria/garante a rotina
    final routine = workoutRepo.upsertRoutine(
      name: routineName.isNotEmpty ? routineName : 'routine',
      description: routineDesc,
      repetitionSchema: repetitionSchema,
    );
    final routineStart = _todayDate();
    routine.startDate = routineStart;
    await routine.save();

    // Reuso em memória (durante esta orquestração)
    final Map<String, Exercise> exerciseBySlug = {};
    final Map<String, WorkoutSession> sessionBySlug = {};

    // 2) Criar blocks (placeholders)
    final Map<String, WorkoutBlock> blocksCreated = {};
    final blocks = (routineJson['blocks_to_create'] as List?) ?? const [];
    int doneBlocks = 0;

    for (final b in blocks) {
      final ph = (b['placeholder_id'] ?? '').toString();
      final blockName = (b['name'] ?? 'bloco').toString();
      final blockDesc = (b['description'] ?? '').toString();

      yield ProgressEvent(
        'Detalhando bloco "$blockName"...',
        0.2 + 0.4 * (doneBlocks / max(1, blocks.length)),
      );

      // 2.1) Block -> Days
      final blockStruct = await llm.getWorkoutBlockStructure(
        blockPlaceholder: {
          'placeholder_id': ph,
          'name': blockName,
          'description': blockDesc
        },
        existingDays: const [],
      );

      final List<WorkoutDay> daysOut = [];
      final daysToCreate = (blockStruct['days_to_create'] as List?) ?? const [];

      for (final dayMeta in daysToCreate) {
        final bool isRest = dayMeta['is_rest'] == true;

        if (isRest) {
          final dayRest = workoutRepo.upsertDay(
            name: (dayMeta['name'] ?? 'descanso').toString(),
            description: (dayMeta['description'] as String?) ?? 'Descanso',
            sessions: const <WorkoutSession>[],
          );
          daysOut.add(dayRest);
          continue;
        }

        // 3) Day -> Sessions + Exercises
        final daySessions = await llm.getWorkoutDaySessions(
          dayPlaceholder: {
            'day_id': (dayMeta['placeholder_id'] ?? '').toString(),
            'name': (dayMeta['name'] ?? 'Dia').toString(),
            'description': (dayMeta['description'] ?? '').toString(),
          },
          existingSessions: const [],
          existingExercises: const [],
          validMuscles: kValidGroupIds.toList(),
        );

        final List<WorkoutSession> sessionsList = [];

        // 3.a) Reusar sessões por nome (nesta execução)
        final reuseSessionsByName =
            List<String>.from(daySessions['reuse_sessions_by_name'] ?? const []);
        for (final sName in reuseSessionsByName) {
          final sSlug = toSlug(sName);
          final reused = sessionBySlug[sSlug];
          if (reused != null) sessionsList.add(reused);
        }

        // 3.b) Criar/atualizar sessões novas
        final sessionsToCreate =
            (daySessions['sessions_to_create'] as List?) ?? const [];

        for (final sess in sessionsToCreate) {
          final List<Exercise> exercisesForSession = [];

          // 3.b.1) Reusar exercícios por nome (nesta execução)
          final reuseEx =
              List<String>.from(sess['reuse_exercises_by_name'] ?? const []);
          for (final exName in reuseEx) {
            final exSlug = toSlug(exName);
            final exObj = exerciseBySlug[exSlug];
            if (exObj != null) exercisesForSession.add(exObj);
          }

          // 3.b.2) Exercícios a criar (aceita "exercises" ou "exercises_to_create")
          final rawList =
              (sess['exercises'] ?? sess['exercises_to_create'] ?? const [])
                  as List;

          for (final ex in rawList) {
            Map<String, dynamic> exMap = {};
            if (ex is Map) {
              exMap = ex.map((k, v) => MapEntry(k.toString(), v));
            }

            // Se vier apenas "hint", pedir detalhamento ao LLM
            final hasName =
                exMap.containsKey('name') && (exMap['name'] ?? '').toString().isNotEmpty;
            if (!hasName && exMap.containsKey('hint')) {
              final detailed = await llm.getExerciseFromHint(
                hint: {'hint': exMap['hint']},
                validMuscles: kValidGroupIds.toList(),
              );
              exMap = {
                'name': (detailed['name'] ?? 'Exercício').toString(),
                'description': (detailed['description'] ?? '').toString(),
                'primary_muscles': List<String>.from(detailed['primary_muscles'] ?? const []),
                'secondary_muscles': List<String>.from(detailed['secondary_muscles'] ?? const []),
                'relevant_metrics': List<String>.from(detailed['relevant_metrics'] ?? const []),
              };
            }

            final canonicalPrimary = List<String>.from(exMap['primary_muscles'] ?? const [])
                .where(isValidGroupId)
                .toList();
            final canonicalSecondary = List<String>.from(exMap['secondary_muscles'] ?? const [])
                .where(isValidGroupId)
                .toList();

            final exercise = workoutRepo.upsertExercise(
              name: (exMap['name'] ?? 'Exercício').toString(),
              description: (exMap['description'] ?? '').toString(),
              primary: canonicalPrimary,
              secondary: canonicalSecondary,
              metrics: List<String>.from(exMap['relevant_metrics'] ?? const []),
            );
            exercisesForSession.add(exercise);
            exerciseBySlug[toSlug(exercise.name)] = exercise;
          }

          // 3.b.3) Criar sessão
          final session = workoutRepo.upsertSession(
            name: (sess['name'] ?? 'Sessão').toString(),
            description: (sess['description'] ?? '').toString(),
            exercises: exercisesForSession,
          );
          sessionsList.add(session);
          sessionBySlug[toSlug(session.name)] = session;
        }

        final dayEntity = workoutRepo.upsertDay(
          name: (dayMeta['name'] ?? 'Dia').toString(),
          description: (dayMeta['description'] ?? '').toString(),
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
    final sequence = blockPlaceholders
        .map((ph) => blocksCreated[ph])
        .where((e) => e != null)
        .cast<WorkoutBlock>()
        .toList();

    final cycleDays = sequence.fold<int>(0, (sum, block) => sum + block.daySlugs.length);
    final routineMeta = (routineJson['routine'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        const <String, dynamic>{};
    final routineEnd = _resolveRoutineEndDate(
      startDate: routineStart,
      routineMeta: routineMeta,
      fallbackDays: cycleDays > 0 ? cycleDays : null,
    );

    final sch = workoutRepo.upsertRoutineSchedule(
      routineSlug: toSlug(routine.name),
      repetitionSchema: repetitionSchema,
      sequence: sequence, // já é List<WorkoutBlock>
      endDate: routineEnd,
    );
    // ignore: avoid_print
    print('.. workout schedule saved: ${sch.routineSlug} -> ${sch.blockSequence}');

    yield const ProgressEvent('Treino concluído!', 1.0);
  }

  // ------------------ DIETA: constrói tudo com progresso ------------------
  Stream<ProgressEvent> buildDietPlan({
    required Map<String, Object?> userProfile,
    required Map<String, String> answers,
  }) async* {
    // ignore: avoid_print
    print('== buildDietPlan (start)');

    final Map<String, num> defaultDayTargets = <String, num>{
      'calories': 2200,
      'protein_g': 160,
      'carbs_g': 230,
      'fat_g': 70,
      'fiber_g': 28,
      'water_l': 2.7,
    };
    final userGoal = (answers['goal'] ?? answers['objetivo'] ?? '').toString();
    final List<String> foodPrefs = const <String>[];

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

    final rName = (routineJson['diet_routine']?['name'] ?? 'diet_plan').toString();
    final rDesc = (routineJson['diet_routine']?['description'] ?? '').toString();
    final repetition =
        (routineJson['diet_routine']?['repetition_schema'] ?? 'Semanal').toString();
    final blockPHs = List<String>.from(
      routineJson['diet_routine']?['block_sequence_placeholders'] ?? const [],
    );

    // cria/garante a rotina base
    final routine = dietRepo.upsertDietRoutine(
      name: rName,
      description: rDesc,
      repetitionSchema: repetition,
      sequence: const [],
    );
    final dietStart = _todayDate();
    routine.startDate = dietStart;
    await routine.save();

    // Reuso em memória durante a execução
    final Map<String, Meal> mealBySlug = {};

    final Map<String, DietBlock> blocksCreated = {};
    final Map<String, String?> blockGoals = {};
    final blocks = (routineJson['blocks_to_create'] as List?) ?? const [];
    int doneBlocks = 0;

    for (final b in blocks) {
      final ph = (b['placeholder_id'] ?? '').toString();
      final bName = (b['name'] ?? 'semana_tipo').toString();
      final bDesc = (b['description'] ?? '').toString();
      final weightGoal =
          DietWeightGoal.normalize((b['weight_goal'] ?? '').toString());
      final existingGoal = weightGoal ??
          dietRepo.getDietBlockGoal(toSlug(bName)) ??
          dietRepo.getDietBlockGoal(ph);
      if (weightGoal != null) {
        blockGoals[ph] = weightGoal;
      } else if (existingGoal != null) {
        blockGoals[ph] = existingGoal;
      }

      yield ProgressEvent(
        'Detalhando bloco de dieta "$bName"...',
        0.2 + 0.5 * (doneBlocks / max(1, blocks.length)),
      );

      // 2) Block -> DietDays
      final blockStruct = await llm.getDietBlockStructure(
        dietBlockPlaceholder: {
          'placeholder_id': ph,
          'name': bName,
          'description': bDesc,
          if (weightGoal != null) 'weight_goal': weightGoal,
        },
        existingDietDays: const [],
        userFoodPrefs: foodPrefs,
      );

      final List<DietDay> days = [];
      final daysToCreate = (blockStruct['days_to_create'] as List?) ?? const [];

      for (final d in daysToCreate) {
        // Exemplo de estrutura base (catálogo)
        final List<Meal> baseMeals = <Meal>[
          dietRepo.upsertMeal(
            name: 'cafe_proteico_aveia',
            description: 'Ovos/claras, aveia e fruta.',
            kcalPer100: 130,
            pPer100: 10,
            cPer100: 15,
            fPer100: 3.5,
          ),
          dietRepo.upsertMeal(
            name: 'almoco_frango_arroz_feijao',
            description: 'Frango magro, arroz e feijão; salada.',
            kcalPer100: 135,
            pPer100: 11,
            cPer100: 17,
            fPer100: 3,
          ),
          dietRepo.upsertMeal(
            name: 'jantar_peixe_batata_legumes',
            description: 'Peixe assado, batata e legumes.',
            kcalPer100: 120,
            pPer100: 12,
            cPer100: 12,
            fPer100: 2.5,
          ),
        ];

        for (final m in baseMeals) {
          mealBySlug[toSlug(m.name)] = m;
        }

        final dayEntity = dietRepo.upsertDietDay(
          name: (d['name'] ?? 'dia_de_semana').toString(),
          description: (d['description'] ?? '').toString(),
          structure: baseMeals,
        );
        days.add(dayEntity);

        // 3) Day Plan com quantidades (via LLM) + persistência (tolerância ±5%)
        final blockGoal = blockGoals[ph];
        final bias = DietWeightGoal.calorieBias(blockGoal);
        final scaledTargets = <String, num>{
          for (final entry in defaultDayTargets.entries)
            entry.key: entry.value * bias,
        };

        final planJson = await llm.getDietDayPlan(
          userProfile: userProfile,
          userGoal: userGoal,
          userFoodPrefs: foodPrefs,
          dietDay: {
            'diet_day_id': (d['placeholder_id'] ?? '').toString(),
            'name': (d['name'] ?? '').toString(),
            'description': (d['description'] ?? '').toString(),
            if (blockGoal != null) 'block_weight_goal': blockGoal,
          },
          existingMealsSummary: baseMeals
              .map((m) => {
                    'name': m.name,
                    'calories_per_100g': m.caloriesPer100g,
                    'protein_per_100g': m.proteinPer100g,
                    'carbs_per_100g': m.carbsPer100g,
                    'fat_per_100g': m.fatPer100g,
              })
              .toList(),
          dayTargets: scaledTargets,
        );

        final items = <dynamic>[];
        final mealsArr = (planJson['meals'] as List?) ?? const [];

        for (final m in mealsArr) {
          final mealName = (m['meal_name_or_id'] ?? 'refeicao').toString();
          final components = (m['components'] as List?) ?? const [];

          // total dos componentes em gramas
          num totalG = 0;
          num calT = 0, pT = 0, cT = 0, fT = 0;

          for (final c in components) {
            final q = num.tryParse('${(c as Map)['quantity_g']}') ?? 0;
            totalG += q;
          }

          final mt = (m['totals'] as Map?) ?? const {};
          calT = num.tryParse('${mt['calories']}') ?? 0;
          pT = num.tryParse('${mt['protein_g']}') ?? 0;
          cT = num.tryParse('${mt['carbs_g']}') ?? 0;
          fT = num.tryParse('${mt['fat_g']}') ?? 0;

          // macros por 100g do consolidado
          double per100(num v) => totalG > 0 ? v * 100 / totalG : 0;
          final cal100 = per100(calT);
          final p100 = per100(pT);
          final c100 = per100(cT);
          final f100 = per100(fT);

          final slug = toSlug(mealName);
          var meal = mealBySlug[slug];
          meal ??= dietRepo.upsertMeal(
            name: mealName,
            description: 'Consolidado automático do plano diário',
            kcalPer100: cal100.toDouble(),
            pPer100: p100.toDouble(),
            cPer100: c100.toDouble(),
            fPer100: f100.toDouble(),
          );
          mealBySlug[slug] = meal;

          final grams = (totalG > 0 ? totalG.toDouble() : 100.0);
          final item = dietRepo.createPlanItem(
            meal: meal,
            label: meal.name,
            grams: grams,
          );
          items.add(item);
        }

        final plan = dietRepo.upsertDietDayPlan(day: dayEntity, items: items);

        // Validação: comparar somas com alvo do dia (±5%)
        final totals = dietRepo.computePlanTotals(plan);
        bool outOfRange(num tgt, num got) {
          if (tgt <= 0) return false;
          final delta = (got - tgt).abs() / tgt;
          return delta > 0.05; // 5%
        }

        final tCal = totals['calories'] ?? 0;
        final tP = totals['protein_g'] ?? 0;
        final tC = totals['carbs_g'] ?? 0;
        final tF = totals['fat_g'] ?? 0;

        if (outOfRange(defaultDayTargets['calories'] ?? 0, tCal) ||
            outOfRange(defaultDayTargets['protein_g'] ?? 0, tP) ||
            outOfRange(defaultDayTargets['carbs_g'] ?? 0, tC) ||
            outOfRange(defaultDayTargets['fat_g'] ?? 0, tF)) {
          dietRepo.annotatePlanNote(
            plan,
            'Fora da tolerância ±5% — ajuste fino recomendado na próxima revisão.',
          );
        }
      }

      final block = dietRepo.upsertDietBlock(
        name: bName,
        description: bDesc,
        daysOrdered: days,
      );
      if (weightGoal != null) {
        dietRepo.setDietBlockGoal(block: block, weightGoal: weightGoal);
      }
      final persistedGoal = blockGoals[ph] ??
          dietRepo.getDietBlockGoal(block.slug) ??
          weightGoal;
      if (persistedGoal != null) {
        blockGoals[ph] = persistedGoal;
      }
      blocksCreated[ph] = block;
      doneBlocks++;
    }

    // 4) DietRoutine final (schedule por blocks)
    final sequence = blockPHs
        .map((ph) => blocksCreated[ph])
        .where((e) => e != null)
        .cast<DietBlock>()
        .toList();

    final dietCycleDays = sequence.fold<int>(0, (sum, block) => sum + block.daySlugs.length);
    final dietRoutineMeta = (routineJson['diet_routine'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        const <String, dynamic>{};
    final dietEnd = _resolveRoutineEndDate(
      startDate: dietStart,
      routineMeta: dietRoutineMeta,
      fallbackDays: dietCycleDays > 0 ? dietCycleDays : null,
    );

    // Persistir a ordem no DietRoutineSchedule
    dietRepo.upsertDietRoutineSchedule(
      routineSlug: toSlug(routine.name),
      repetitionSchema: repetition,
      sequence: sequence,
      endDate: dietEnd,
    );

    yield const ProgressEvent('Dieta concluída!', 1.0);
  }
}

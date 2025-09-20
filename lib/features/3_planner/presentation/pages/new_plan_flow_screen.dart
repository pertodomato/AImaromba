// lib/features/3_planner/presentation/pages/new_plan_flow_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/llm_service.dart';

import 'package:fitapp/features/3_planner/presentation/pages/controllers/planner_controller.dart';
import 'package:fitapp/features/3_planner/application/planner_orchestrator.dart';
import 'package:fitapp/features/3_planner/infrastructure/llm/llm_client_impl.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_workout_repo.dart';
import 'package:fitapp/features/3_planner/infrastructure/persistence/hive_diet_repo.dart';

// Models
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/workout_routine.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';
import 'package:fitapp/core/models/user_profile.dart';

import 'planner_screen.dart';
import 'plan_overview_page.dart';

class NewPlanFlowScreen extends StatefulWidget {
  const NewPlanFlowScreen({super.key});
  @override
  State<NewPlanFlowScreen> createState() => _NewPlanFlowScreenState();
}

class _NewPlanFlowScreenState extends State<NewPlanFlowScreen> {
  late final PlannerController controller;
  late final VoidCallback _controllerListener;

  final TextEditingController _goal = TextEditingController();
  final Map<String, TextEditingController> _answers = {};
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    final hive = context.read<HiveService>();
    final llmService = context.read<LLMService>();

    // Cliente do LLM
    final llm = LLMClientImpl(llmService);

    // Repositório de Treino (boxes tipadas)
    final workoutRepo = HiveWorkoutRepo(
      exBox: hive.getBox<Exercise>('exercises'),
      sessBox: hive.getBox<WorkoutSession>('workout_sessions'),
      dayBox: hive.getBox<WorkoutDay>('workout_days'),
      routineBox: hive.getBox<WorkoutRoutine>('workout_routines'),
      blockBox: hive.getBox<WorkoutBlock>('workout_blocks'),
      routineScheduleBox: hive.getBox<WorkoutRoutineSchedule>('routine_schedules'),
    );

    // Repositório de Dieta
    final dietRepo = HiveDietRepo.fromService(hive);

    // Orquestrador
    final orchestrator = PlannerOrchestrator(
      llm: llm,
      workoutRepo: workoutRepo,
      dietRepo: dietRepo,
    );

    controller = PlannerController(orchestrator: orchestrator);

    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    controller.addListener(_controllerListener);

    // Log de criação
    // ignore: avoid_print
    print('NewPlanFlowScreen init: repos criados e controller pronto');
  }

  @override
  void dispose() {
    _goal.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    _pageController.dispose();
    controller.removeListener(_controllerListener);
    controller.dispose();
    super.dispose();
  }

  Map<String, Object?> _profileToJson(UserProfile p) => {
        'name': p.name,
        'height': p.height,
        'weight': p.weight,
        'gender': p.gender,
        'birthDate': p.birthDate?.toIso8601String(),
        'bodyFatPercentage': p.bodyFatPercentage,
      };

  @override
  Widget build(BuildContext context) {
    final hive = context.watch<HiveService>();
    final profile = hive.getUserProfile();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Plano Personalizado'),
        actions: [
          IconButton(
            tooltip: 'Calendário',
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlannerScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildContent(profile)),
    );
  }

  Widget _buildContent(UserProfile profile) {
    switch (controller.state.step) {
      case PlanUiStep.generating:
        return _loading(controller.state.message ?? 'Gerando...');
      case PlanUiStep.summary:
        return _summaryView();
      case PlanUiStep.questions:
        return _questionsView();
      case PlanUiStep.error:
        return Center(child: Text(controller.state.message ?? 'Erro'));
      case PlanUiStep.goal:
      default:
        return _goalView(profile);
    }
  }

  Widget _loading(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _goalView(UserProfile profile) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Qual é o seu principal objetivo?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goal,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex: Ganhar massa e definir, 4x/semana.',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final llm = context.read<LLMService>();
                if (!llm.isAvailable()) {
                  _showError('Configure a chave de API em Perfil.');
                  return;
                }
                // ignore: avoid_print
                print('Começar -> solicitando perguntas | goal="${_goal.text.trim()}"');
                controller.fetchQuestions(
                  userProfile: _profileToJson(profile),
                  goal: _goal.text.trim(),
                );
              },
              child: const Text('Começar'),
            ),
          ],
        ),
      );

  Widget _questionsView() {
    final qs = controller.state.questions;

    if (_answers.isEmpty) {
      for (final q in qs) {
        _answers[q.key] = TextEditingController();
      }
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: qs.length,
            onPageChanged: (p) => setState(() => _currentPage = p),
            itemBuilder: (_, i) {
              final q = qs[i];
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      q.text,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _answers[q.key],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_currentPage > 0)
                TextButton.icon(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeIn,
                  ),
                  icon: const Icon(Icons.arrow_back_ios),
                  label: const Text('Anterior'),
                ),
              const Spacer(),
              if (_currentPage < qs.length - 1)
                ElevatedButton.icon(
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeIn,
                  ),
                  label: const Text('Próximo'),
                  icon: const Icon(Icons.arrow_forward_ios),
                ),
              if (_currentPage == qs.length - 1)
                ElevatedButton(
                  onPressed: () {
                    // ignore: avoid_print
                    print('Gerar Resumo -> enviando respostas');
                    controller.generateSummaries(
                      userProfile: _profileToJson(
                        context.read<HiveService>().getUserProfile(),
                      ),
                      goal: _goal.text.trim(),
                      answers: _answers.map((k, v) => MapEntry(k, v.text.trim())),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Gerar Resumo'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryView() {
    final s = controller.state.summaries;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo do Treino', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(s['workout_summary'] ?? ''),
          const SizedBox(height: 16),
          Text('Resumo da Nutrição', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(s['nutrition_summary'] ?? ''),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  // ignore: avoid_print
                  print('Resumo -> voltar para perguntas');
                  controller.fetchQuestions(
                    userProfile: _profileToJson(
                      context.read<HiveService>().getUserProfile(),
                    ),
                    goal: _goal.text.trim(),
                  );
                },
                child: const Text('Voltar'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  // ignore: avoid_print
                  print('Confirmar e Construir -> iniciando orquestração');
                  await controller.confirmAndBuild(
                    userProfile: _profileToJson(
                      context.read<HiveService>().getUserProfile(),
                    ),
                    answers: _answers.map((k, v) => MapEntry(k, v.text.trim())),
                  );
                  if (!mounted) return;
                  // ignore: avoid_print
                  print('Build finalizado -> abrindo revisão');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanOverviewPage()),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirmar e Construir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erro'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

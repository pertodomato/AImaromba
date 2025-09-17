import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:muscle_selector/muscle_selector.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/utils/json_safety.dart';

enum PlanStep { goal, questions, generating }

class NewPlanFlowScreen extends StatefulWidget {
  const NewPlanFlowScreen({super.key});

  @override
  State<NewPlanFlowScreen> createState() => _NewPlanFlowScreenState();
}

class _NewPlanFlowScreenState extends State<NewPlanFlowScreen> {
  PlanStep _currentStep = PlanStep.goal;
  String _loadingMessage = 'Aguarde...';

  final TextEditingController _goalController = TextEditingController();
  final PageController _pageController = PageController();
  final Uuid _uuid = const Uuid();

  final Map<String, TextEditingController> _answers = {};
  List<Map<String, dynamic>> _questions = [];
  int _currentPage = 0;

  @override
  void dispose() {
    _goalController.dispose();
    _pageController.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInitialQuestions() async {
    if (_goalController.text.trim().isEmpty) {
      _showError('Descreva seu objetivo.');
      return;
    }

    setState(() {
      _currentStep = PlanStep.generating;
      _loadingMessage = 'IA preparando perguntas...';
    });

    final llm = context.read<LLMService>();
    final hive = context.read<HiveService>();

    if (!llm.isAvailable()) {
      _showError('Configure a chave de API em Perfil.');
      setState(() => _currentStep = PlanStep.goal);
      return;
    }

    final user = hive.getUserProfile();
    final template = await rootBundle.loadString('assets/prompts/planner_get_questions.txt');
    final prompt = template
        .replaceAll('{user_profile}', jsonEncode(_profileToJson(user)))
        .replaceAll('{user_goal}', _goalController.text.trim());

    try {
      final response = await llm.generateResponse(prompt);
      final decoded = safeDecodeMap(response);
      final q = List<Map<String, dynamic>>.from(decoded['questions'] ?? []);
      if (q.isEmpty) throw Exception('JSON sem perguntas');

      _questions = q;
      _answers.clear();
      for (final m in _questions) {
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        _answers[id] = TextEditingController();
      }
      setState(() => _currentStep = PlanStep.questions);
    } catch (e) {
      _showError('Erro ao gerar perguntas: $e');
      setState(() => _currentStep = PlanStep.goal);
    }
  }

  Future<void> _submitPlan() async {
    setState(() {
      _currentStep = PlanStep.generating;
      _loadingMessage = 'Analisando respostas...';
    });

    final llm = context.read<LLMService>();
    final hive = context.read<HiveService>();
    final user = hive.getUserProfile();
    final userAnswers = _answers.map((k, v) => MapEntry(k, v.text.trim()));

    try {
      // 1) Estrutura da rotina de TREINO
      setState(() => _loadingMessage = 'Criando estrutura da rotina de treino...');
      final routineStructure = await _generateRoutineStructure(llm, user, userAnswers);

      final routineData = routineStructure['routine'];
      final daysToCreateData = List<Map<String, dynamic>>.from(routineStructure['days_to_create'] ?? []);

      final dayBox = hive.getBox<WorkoutDay>('workout_days');
      final sessionBox = hive.getBox<WorkoutSession>('workout_sessions');
      final exBox = hive.getBox<Exercise>('exercises');

      final List<WorkoutDay> createdDays = [];

      // 2) Criar cada dia → sessões → exercícios
      for (final dayData in daysToCreateData) {
        setState(() => _loadingMessage = "Detalhando dia '${dayData['name']}'...");
        final sessionsStructure = await _generateDayStructure(llm, dayData);
        final sessionsToCreateData = List<Map<String, dynamic>>.from(sessionsStructure['sessions_to_create'] ?? []);

        final List<WorkoutSession> createdSessions = [];

        for (final sessionData in sessionsToCreateData) {
          setState(() => _loadingMessage = "Montando sessão '${sessionData['name']}'...");
          final exStructure = await _generateSessionStructure(llm, sessionData);
          final exToCreateData = List<Map<String, dynamic>>.from(exStructure['exercises_to_create'] ?? []);
          final List<Exercise> createdExercises = [];

          for (final exerciseData in exToCreateData) {
            setState(() => _loadingMessage = "Criando exercício '${exerciseData['name']}'...");
            final exJson = await _generateExercise(llm, exerciseData);
            final newEx = Exercise(
              id: _uuid.v4(),
              name: (exJson['name'] ?? '').toString(),
              description: (exJson['description'] ?? '').toString(),
              primaryMuscles: List<String>.from(exJson['primary_muscles'] ?? const <String>[]),
              secondaryMuscles: List<String>.from(exJson['secondary_muscles'] ?? const <String>[]),
              relevantMetrics: List<String>.from(exJson['relevant_metrics'] ?? const <String>[]),
            );
            await exBox.add(newEx);
            createdExercises.add(newEx);
          }

          final newSession = WorkoutSession(
            id: _uuid.v4(),
            name: (sessionData['name'] ?? '').toString(),
            description: (sessionData['description'] ?? '').toString(),
            exercises: HiveList(exBox)..addAll(createdExercises),
          );
          await sessionBox.add(newSession);
          createdSessions.add(newSession);
        }

        final newDay = WorkoutDay(
          id: _uuid.v4(),
          name: (dayData['name'] ?? '').toString(),
          description: (dayData['description'] ?? '').toString(),
          sessions: HiveList(sessionBox)..addAll(createdSessions),
        );
        await dayBox.add(newDay);
        createdDays.add(newDay);
      }

      // 3) Persistir rotina de TREINO
      final routine = WorkoutRoutine(
        id: _uuid.v4(),
        name: (routineData['name'] ?? '').toString(),
        description: (routineData['description'] ?? '').toString(),
        startDate: DateTime.now(),
        repetitionSchema: (routineData['repetition_schema'] ?? '').toString(),
        days: HiveList(dayBox)..addAll(createdDays),
      );
      await hive.getBox<WorkoutRoutine>('workout_routines').add(routine);

      // 4) DIETA
      setState(() => _loadingMessage = 'Criando rotina de dieta...');
      await _generateAndPersistDiet(llm, user);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plano de treino e dieta criado!')));
    } catch (e) {
      _showError('Erro durante criação do plano: $e');
      setState(() => _currentStep = PlanStep.questions);
    }
  }

  // ====== LLM prompts para TREINO ======

  Future<Map<String, dynamic>> _generateRoutineStructure(
    LLMService llm,
    UserProfile profile,
    Map<String, String> answers,
  ) async {
    final template = await rootBundle.loadString('assets/prompts/planner_get_routine.txt');
    final prompt = template
        .replaceAll('{user_profile}', jsonEncode(_profileToJson(profile)))
        .replaceAll('{user_answers}', jsonEncode(answers))
        .replaceAll('{existing_workout_days}', '[]');
    final response = await llm.generateResponse(prompt);
    return safeDecodeMap(response);
  }

  Future<Map<String, dynamic>> _generateDayStructure(LLMService llm, Map<String, dynamic> dayData) async {
    final prompt = '''
SYSTEM: Você é um personal trainer. Detalhe um dia de treino com sessões.
Dia: ${jsonEncode(dayData)}
Sessões existentes: []

Responda JSON estrito:
{
  "day_id": "${dayData['placeholder_id'] ?? dayData['name']}",
  "sessions_to_create": [
    {"name": "Aquecimento Articular", "description": "5-10 min"},
    {"name": "Principal - ${dayData['name']}", "description": "Exercícios compostos e isolados do dia."}
  ]
}
''';
    final response = await llm.generateResponse(prompt);
    return safeDecodeMap(response);
  }

  Future<Map<String, dynamic>> _generateSessionStructure(LLMService llm, Map<String, dynamic> sessionData) async {
    final prompt = '''
SYSTEM: Você é um personal trainer. Detalhe uma sessão com exercícios.
Sessão: ${jsonEncode(sessionData)}
Exercícios existentes: []

Responda JSON estrito:
{
  "session_id": "${sessionData['name']}",
  "exercises_to_create": [
    {"name": "Supino Reto com Barra", "description": "Execução padrão com segurança."},
    {"name": "Desenvolvimento Militar com Halteres", "description": "Execução controlada."},
    {"name": "Tríceps na Polia Alta", "description": "Extensão completa do cotovelo."}
  ]
}
''';
    final response = await llm.generateResponse(prompt);
    return safeDecodeMap(response);
  }

  Future<Map<String, dynamic>> _generateExercise(LLMService llm, Map<String, dynamic> exerciseData) async {
    final validMuscles = jsonEncode(Muscle.values.map((m) => m.name).toList());
    final prompt = '''
SYSTEM: Você é especialista em cinesiologia. Gere os campos do exercício.
Entrada: ${jsonEncode(exerciseData)}
Músculos válidos (enum do app): $validMuscles

Responda JSON estrito:
{
  "name": "${exerciseData['name']}",
  "description": "${(exerciseData['description'] ?? 'N/A').toString()}",
  "primary_muscles": ["peitoral"],
  "secondary_muscles": ["deltoide_anterior","tríceps"],
  "relevant_metrics": ["Peso","Repetições","Séries"]
}
''';
    final response = await llm.generateResponse(prompt);
    return safeDecodeMap(response);
  }

  // ====== LLM prompts para DIETA ======

  Future<Map<String, dynamic>> _generateDietStructure(
    LLMService llm,
    UserProfile profile,
    Map<String, String> answers,
  ) async {
    final prompt = '''
SYSTEM: Você é nutricionista. Crie uma rotina de dieta com placeholders de dias e lista de dias a criar.
Responda JSON estrito:
{
  "routine": {
    "name": "string",
    "description": "string",
    "repetition_schema": "Semanal|Quinzenal|Mensal",
    "day_sequence_placeholders": ["dia_normal","dia_fim_semana"]
  },
  "days_to_create": [
    {"placeholder_id":"dia_normal","name":"Dia Normal","description":"Dia padrão de semana","meals":[
      {"label":"Café da manhã","suggestions":["ovos","aveia"]},
      {"label":"Almoço","suggestions":["frango","arroz","feijão"]},
      {"label":"Jantar","suggestions":["carne","legumes"]}
    ]},
    {"placeholder_id":"dia_fim_semana","name":"Fim de Semana","description":"Dia com flexibilidade","meals":[
      {"label":"Livre 1","suggestions":["refeição livre controlada"]}
    ]}
  ]
}
Perfil: ${jsonEncode(_profileToJson(profile))}
Respostas: ${jsonEncode(answers)}
''';
    final resp = await llm.generateResponse(prompt);
    return safeDecodeMap(resp);
  }

  Future<void> _generateAndPersistDiet(LLMService llm, UserProfile user) async {
    final hive = context.read<HiveService>();
    final dayBox = hive.getBox<DietDay>('diet_days');
    final routineBox = hive.getBox<DietRoutine>('diet_routines');

    final answers = _answers.map((k, v) => MapEntry(k, v.text.trim()));
    final dietStruct = await _generateDietStructure(llm, user, answers);

    final routineData = dietStruct['routine'];
    final daysToCreate = List<Map<String, dynamic>>.from(dietStruct['days_to_create'] ?? []);

    final createdDays = <DietDay>[];
    for (final d in daysToCreate) {
      final day = DietDay(
        id: _uuid.v4(),
        name: (d['name'] ?? '').toString(),
        description: (d['description'] ?? '').toString(),
      );
      await dayBox.add(day);
      createdDays.add(day);
    }

    final routine = DietRoutine(
      id: _uuid.v4(),
      name: (routineData['name'] ?? '').toString(),
      description: (routineData['description'] ?? '').toString(),
      startDate: DateTime.now(),
      repetitionSchema: (routineData['repetition_schema'] ?? '').toString(),
      days: HiveList(dayBox)..addAll(createdDays),
    );
    await routineBox.add(routine);
  }

  Map<String, dynamic> _profileToJson(UserProfile p) => {
        'name': p.name,
        'height': p.height,
        'weight': p.weight,
        'gender': p.gender,
        'birthDate': p.birthDate?.toIso8601String(),
        'bodyFatPercentage': p.bodyFatPercentage,
      };

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erro'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Plano Personalizado'),
        leading: _currentStep == PlanStep.questions
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = PlanStep.goal),
              )
            : null,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case PlanStep.generating:
        return Center(
          key: const ValueKey('generating'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_loadingMessage, textAlign: TextAlign.center),
            ],
          ),
        );
      case PlanStep.questions:
        return Column(
          key: const ValueKey('questions'),
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _questions.length,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemBuilder: (_, i) {
                  final q = _questions[i];
                  final id = (q['id'] ?? '').toString();
                  final text = (q['text'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(text, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _answers[id],
                          decoration: const InputDecoration(border: OutlineInputBorder()),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  if (_currentPage < _questions.length - 1)
                    ElevatedButton.icon(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeIn,
                      ),
                      label: const Text('Próximo'),
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  if (_currentPage == _questions.length - 1)
                    ElevatedButton(
                      onPressed: _submitPlan,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Gerar Plano'),
                    ),
                ],
              ),
            ),
          ],
        );
      case PlanStep.goal:
      default:
        return Padding(
          key: const ValueKey('goal'),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Qual é o seu principal objetivo?',
                  style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _goalController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Ganhar massa e definir, 4x/semana.',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchInitialQuestions, child: const Text('Começar')),
            ],
          ),
        );
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/core/services/hive_service.dart';

enum PlanStep { goal, questions, generating }

class NewPlanFlowScreen extends StatefulWidget {
  const NewPlanFlowScreen({super.key});
  @override
  State<NewPlanFlowScreen> createState() => _NewPlanFlowScreenState();
}

class _NewPlanFlowScreenState extends State<NewPlanFlowScreen> {
  PlanStep _currentStep = PlanStep.goal;
  String _loadingMessage = 'Aguarde...';
  List<Map<String, dynamic>> _questions = [];
  final Map<String, TextEditingController> _answers = {};
  final TextEditingController _goalController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Uuid _uuid = const Uuid();

  @override
  void dispose() {
    _goalController.dispose();
    _pageController.dispose();
    for (var c in _answers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _fetchInitialQuestions() async {
    if (_goalController.text.isEmpty) { _showError("Descreva seu objetivo."); return; }

    setState(() { _currentStep = PlanStep.generating; _loadingMessage = 'IA preparando perguntas...'; });

    final llm = context.read<LLMService>();
    final hive = context.read<HiveService>();

    if (!llm.isAvailable()) { _showError("Configure a chave de API em Perfil."); _currentStep = PlanStep.goal; setState((){}); return; }

    final user = hive.getUserProfile();
    final template = await rootBundle.loadString('assets/prompts/planner_get_questions.txt');
    final prompt = template
      .replaceAll('{user_profile}', jsonEncode(_profileToJson(user)))
      .replaceAll('{user_goal}', _goalController.text);

    try {
      final response = await llm.generateResponse(prompt);
      final decoded = jsonDecode(response);
      _questions = List<Map<String, dynamic>>.from(decoded['questions']);
      for (var q in _questions) { _answers[q['id']] = TextEditingController(); }
      setState(() { _currentStep = PlanStep.questions; });
    } catch (e) {
      _showError("Erro ao gerar perguntas: $e");
      setState(() { _currentStep = PlanStep.goal; });
    }
  }

  Future<void> _submitPlan() async {
    setState(() { _currentStep = PlanStep.generating; _loadingMessage = "Analisando respostas..."; });

    final llm = context.read<LLMService>();
    final hive = context.read<HiveService>();
    final user = hive.getUserProfile();
    final userAnswers = _answers.map((k, v) => MapEntry(k, v.text));

    try {
      // 1) Estrutura da rotina
      setState(() { _loadingMessage = "Criando estrutura da rotina..."; });
      final routineStructure = await _generateRoutineStructure(llm, user, userAnswers);

      final routineData = routineStructure['routine'];
      final daysToCreateData = List<Map<String, dynamic>>.from(routineStructure['days_to_create']);

      final dayBox = hive.getBox<WorkoutDay>('workout_days');
      final sessionBox = hive.getBox<WorkoutSession>('workout_sessions');
      final exBox = hive.getBox<Exercise>('exercises');

      final List<WorkoutDay> createdDays = [];

      // 2) Criar cada dia
      for (var dayData in daysToCreateData) {
        setState(() { _loadingMessage = "Detalhando dia '${dayData['name']}'..."; });
        final sessionsStructure = await _generateDayStructure(llm, dayData);
        final sessionsToCreateData = List<Map<String, dynamic>>.from(sessionsStructure['sessions_to_create']);

        final List<WorkoutSession> createdSessions = [];

        for (var sessionData in sessionsToCreateData) {
          setState(() { _loadingMessage = "Montando sessão '${sessionData['name']}'..."; });
          final exStructure = await _generateSessionStructure(llm, sessionData);
          final exToCreateData = List<Map<String, dynamic>>.from(exStructure['exercises_to_create']);
          final List<Exercise> createdExercises = [];

          for (var exerciseData in exToCreateData) {
            setState(() { _loadingMessage = "Criando exercício '${exerciseData['name']}'..."; });
            final exJson = await _generateExercise(llm, exerciseData);
            final newEx = Exercise(
              id: _uuid.v4(),
              name: exJson['name'],
              description: exJson['description'],
              primaryMuscles: List<String>.from(exJson['primary_muscles']),
              secondaryMuscles: List<String>.from(exJson['secondary_muscles']),
              relevantMetrics: List<String>.from(exJson['relevant_metrics']),
            );
            await exBox.add(newEx);
            createdExercises.add(newEx);
          }

          final newSession = WorkoutSession(
            id: _uuid.v4(),
            name: sessionData['name'],
            description: sessionData['description'] ?? '',
            exercises: HiveList(exBox)..addAll(createdExercises),
          );
          await sessionBox.add(newSession);
          createdSessions.add(newSession);
        }

        final newDay = WorkoutDay(
          id: _uuid.v4(),
          name: dayData['name'],
          description: dayData['description'] ?? '',
          sessions: HiveList(sessionBox)..addAll(createdSessions),
        );
        await dayBox.add(newDay);
        createdDays.add(newDay);
      }

      final routine = WorkoutRoutine(
        id: _uuid.v4(),
        name: routineData['name'],
        description: routineData['description'],
        startDate: DateTime.now(),
        repetitionSchema: routineData['repetition_schema'],
        days: HiveList(dayBox)..addAll(createdDays),
      );
      await hive.getBox<WorkoutRoutine>('workout_routines').add(routine);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plano de treino criado!')));
    } catch (e) {
      _showError("Erro durante criação do plano: $e");
      setState(() { _currentStep = PlanStep.questions; });
    }
  }

  Future<Map<String, dynamic>> _generateRoutineStructure(LLMService llm, UserProfile profile, Map<String, String> answers) async {
    final template = await rootBundle.loadString('assets/prompts/planner_get_routine.txt');
    // Reuso: insira campos extras que seu template suporte (se necessário).
    final prompt = template
      .replaceAll('{user_profile}', jsonEncode(_profileToJson(profile)))
      .replaceAll('{user_answers}', jsonEncode(answers))
      .replaceAll('{existing_workout_days}', '[]');
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }

  Future<Map<String, dynamic>> _generateDayStructure(LLMService llm, Map<String, dynamic> dayData) async {
    final prompt = '''
SYSTEM: Você é um personal trainer. Detalhe um dia de treino com sessões.
Dia: ${jsonEncode(dayData)}
Sessões existentes: []

Retorne JSON estrito:
{
  "day_id": "${dayData['placeholder_id']}",
  "sessions_to_create": [
    {"name": "Aquecimento Articular", "description": "5-10 min"},
    {"name": "Principal - ${dayData['name']}", "description": "Exercícios compostos e isolados do dia."}
  ]
}
''';
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }

  Future<Map<String, dynamic>> _generateSessionStructure(LLMService llm, Map<String, dynamic> sessionData) async {
    final prompt = '''
SYSTEM: Você é um personal trainer. Detalhe uma sessão com exercícios.
Sessão: ${jsonEncode(sessionData)}
Exercícios existentes: []

Retorne JSON estrito:
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
    return jsonDecode(response);
  }

  Future<Map<String, dynamic>> _generateExercise(LLMService llm, Map<String, dynamic> exerciseData) async {
    final validMuscles = jsonEncode(Muscle.values.map((m) => m.name).toList());
    final prompt = '''
SYSTEM: Especialista em cinesiologia. Detalhe exercício.
Entrada: ${jsonEncode(exerciseData)}
Músculos válidos: $validMuscles

Retorne JSON estrito:
{
  "name": "${exerciseData['name']}",
  "description": "${exerciseData['description'] ?? 'N/A'}",
  "primary_muscles": ["peitoral"],
  "secondary_muscles": ["deltoide_anterior","tríceps"],
  "relevant_metrics": ["Peso","Repetições","Séries"]
}
''';
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
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
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Erro'),
      content: Text(msg),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Plano Personalizado'),
        leading: _currentStep == PlanStep.questions ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = PlanStep.goal)) : null,
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage, textAlign: TextAlign.center),
          ]),
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
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(q['text'], style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextFormField(controller: _answers[q['id']], decoration: const InputDecoration(border: OutlineInputBorder()), maxLines: 3),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (_currentPage > 0) TextButton.icon(onPressed: ()=>_pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeIn), icon: const Icon(Icons.arrow_back_ios), label: const Text('Anterior')),
                const Spacer(),
                if (_currentPage < _questions.length - 1)
                  ElevatedButton.icon(onPressed: ()=>_pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeIn), label: const Text('Próximo'), icon: const Icon(Icons.arrow_forward_ios)),
                if (_currentPage == _questions.length - 1)
                  ElevatedButton(onPressed: _submitPlan, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Gerar Plano')),
              ]),
            ),
          ],
        );
      case PlanStep.goal:
      default:
        return Padding(
          key: const ValueKey('goal'),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Qual é o seu principal objetivo?', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(controller: _goalController, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ex: Ganhar massa e definir, 4x/semana.') ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchInitialQuestions, child: const Text('Começar')),
          ]),
        );
    }
  }
}

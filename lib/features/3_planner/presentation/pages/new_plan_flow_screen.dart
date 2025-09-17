import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

// Importe todos os seus modelos e serviços necessários
import 'package:seu_app/core/models/user_profile.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_session.dart';
import 'package:seu_app/core/models/workout_day.dart';
import 'package:seu_app/core/models/workout_routine.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/core/services/hive_service.dart';


class NewPlanFlowScreen extends StatefulWidget {
  const NewPlanFlowScreen({super.key});

  @override
  State<NewPlanFlowScreen> createState() => _NewPlanFlowScreenState();
}

class _NewPlanFlowScreenState extends State<NewPlanFlowScreen> {
  // Enum para controlar o estado da tela
  enum PlanStep { goal, questions, generating }

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
    for (var controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ETAPA 1: Inicia o fluxo, obtendo as perguntas da IA com base no objetivo.
  Future<void> _fetchInitialQuestions() async {
    if (_goalController.text.isEmpty) {
      _showErrorDialog("Por favor, descreva seu objetivo.");
      return;
    }

    setState(() {
      _currentStep = PlanStep.generating;
      _loadingMessage = 'IA está preparando suas perguntas...';
    });

    final llmService = context.read<LLMService>();
    final hiveService = context.read<HiveService>();

    if (!llmService.isAvailable()) {
      _showErrorDialog("Chave de API não configurada. Por favor, adicione-a em seu perfil.");
      setState(() { _currentStep = PlanStep.goal; });
      return;
    }

    final userProfile = hiveService.getUserProfile();
    final userGoal = _goalController.text;

    final prompt = """
      SYSTEM_PROMPT: Você é um personal trainer e nutricionista especialista. Seu objetivo é criar um plano de treino e dieta altamente personalizado. Você deve gerar perguntas para coletar informações essenciais do usuário.
      - Perfil do Usuário: ${jsonEncode(userProfile.toJson())}
      - Objetivo Principal: "$userGoal"

      Sua tarefa é gerar EXATAMENTE 5 perguntas cruciais em português para refinar o plano.
      Retorne sua resposta ESTRITAMENTE no seguinte formato JSON, sem nenhum texto adicional:
      {
        "questions": [
          {"id": "q1", "text": "Qual é o seu nível de acesso a equipamentos de treino? (Ex: academia completa, halteres em casa, nenhum)"},
          {"id": "q2", "text": "Quantos dias por semana você pode treinar e por quanto tempo em média por sessão?"},
          {"id": "q3", "text": "Você possui alguma restrição alimentar, alergia ou alimentos que não gosta?"},
          {"id": "q4", "text": "Qual sua experiência com musculação? (Iniciante, Intermediário, Avançado)"},
          {"id": "q5", "text": "Existe alguma lesão ou condição médica que devemos considerar ao montar os exercícios?"}
        ]
      }
    """;

    try {
      final response = await llmService.generateResponse(prompt);
      final decodedResponse = jsonDecode(response);
      setState(() {
        _questions = List<Map<String, dynamic>>.from(decodedResponse['questions']);
        for (var q in _questions) {
          _answers[q['id']] = TextEditingController();
        }
        _currentStep = PlanStep.questions;
      });
    } catch (e) {
      _showErrorDialog("Erro ao gerar perguntas: $e");
      setState(() { _currentStep = PlanStep.goal; });
    }
  }

  /// ETAPA 2: Processo completo de submissão e criação encadeada do plano.
  Future<void> _submitPlan() async {
    setState(() {
      _currentStep = PlanStep.generating;
      _loadingMessage = "Analisando suas respostas...";
    });

    final llm = context.read<LLMService>();
    final hive = context.read<HiveService>();
    final userProfile = hive.getUserProfile();
    final userAnswers = _answers.map((key, value) => MapEntry(key, value.text));
    
    try {
      // 2.1: Gerar a estrutura da Rotina e a lista de Dias a Criar
      setState(() { _loadingMessage = "IA está criando a estrutura da sua rotina..."; });
      final routineStructureJson = await _generateRoutineStructure(llm, userProfile, userAnswers);
      final routineData = routineStructureJson['routine'];
      final daysToCreateData = List<Map<String, dynamic>>.from(routineStructureJson['days_to_create']);

      final List<WorkoutDay> createdDays = [];

      // 2.2: Loop para criar cada Dia de Treino
      for (var dayData in daysToCreateData) {
        setState(() { _loadingMessage = "IA está detalhando o '${dayData['name']}'..."; });
        final sessionsStructureJson = await _generateDayStructure(llm, dayData, hive.getBox<WorkoutSession>('workout_sessions').values.toList());
        final sessionsToCreateData = List<Map<String, dynamic>>.from(sessionsStructureJson['sessions_to_create']);
        final List<WorkoutSession> createdSessions = [];

        // 2.3: Loop para criar cada Sessão de Treino
        for (var sessionData in sessionsToCreateData) {
           setState(() { _loadingMessage = "IA está montando a sessão '${sessionData['name']}'..."; });
           final exercisesStructureJson = await _generateSessionStructure(llm, sessionData, hive.getBox<Exercise>('exercises').values.toList());
           final exercisesToCreateData = List<Map<String, dynamic>>.from(exercisesStructureJson['exercises_to_create']);
           final List<Exercise> createdExercises = [];

           // 2.4: Loop para criar cada Exercício novo
           for (var exerciseData in exercisesToCreateData) {
              setState(() { _loadingMessage = "IA está criando o exercício '${exerciseData['name']}'..."; });
              final exerciseJson = await _generateExercise(llm, exerciseData);
              final newExercise = Exercise(
                id: _uuid.v4(),
                name: exerciseJson['name'],
                description: exerciseJson['description'],
                primaryMuscles: List<String>.from(exerciseJson['primary_muscles']),
                secondaryMuscles: List<String>.from(exerciseJson['secondary_muscles']),
                relevantMetrics: List<String>.from(exerciseJson['relevant_metrics']),
              );
              await hive.getBox<Exercise>('exercises').add(newExercise);
              createdExercises.add(newExercise);
           }
           // Salva a Sessão com os exercícios novos
           final newSession = WorkoutSession(id: _uuid.v4(), name: sessionData['name'], description: sessionData['description'], exercises: HiveList(hive.getBox<Exercise>('exercises'))..addAll(createdExercises));
           await hive.getBox<WorkoutSession>('workout_sessions').add(newSession);
           createdSessions.add(newSession);
        }
        // Salva o Dia de Treino com as sessões
        final newDay = WorkoutDay(id: _uuid.v4(), name: dayData['name'], description: dayData['description'], sessions: HiveList(hive.getBox<WorkoutSession>('workout_sessions'))..addAll(createdSessions));
        await hive.getBox<WorkoutDay>('workout_days').add(newDay);
        createdDays.add(newDay);
      }

      // 2.5: Montar e salvar a Rotina Final
      final newRoutine = WorkoutRoutine(
        id: _uuid.v4(),
        name: routineData['name'],
        description: routineData['description'],
        startDate: DateTime.now(),
        repetitionSchema: routineData['repetition_schema'],
        days: HiveList(hive.getBox<WorkoutDay>('workout_days'))..addAll(createdDays),
      );
      await hive.getBox<WorkoutRoutine>('workout_routines').add(newRoutine);
      
      if(mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seu novo plano de treino foi criado com sucesso!')));
      }

    } catch (e) {
      _showErrorDialog("Ocorreu um erro durante a criação do plano: $e \n\nPor favor, tente novamente.");
      setState(() { _currentStep = PlanStep.questions; });
    }
  }

  // Funções auxiliares para cada chamada de IA (com seus próprios prompts)
  Future<Map<String, dynamic>> _generateRoutineStructure(LLMService llm, UserProfile profile, Map<String, String> answers) async {
    final prompt = """
      SYSTEM_PROMPT: Você é um personal trainer especialista. Baseado nas informações completas do usuário, crie a estrutura da rotina de treino.
      - Perfil: ${jsonEncode(profile.toJson())}
      - Objetivo: "${_goalController.text}"
      - Respostas do Questionário: ${jsonEncode(answers)}
      - Dias de treino existentes no DB: []

      Sua tarefa é criar a rotina de treino e especificar quais NOVOS dias de treino precisam ser criados. Não use dias existentes.
      Retorne sua resposta ESTRITAMENTE no seguinte formato JSON:
      {
        "routine": {
          "name": "Rotina de Hipertrofia Focada (3x/semana)",
          "description": "Uma rotina focada em ganho de massa muscular, baseada nas respostas do usuário.",
          "repetition_schema": "Semanal",
          "day_sequence": ["placeholder_dia_A", "descanso", "placeholder_dia_B", "descanso", "placeholder_dia_C", "descanso", "descanso"]
        },
        "days_to_create": [
          {"placeholder_id": "placeholder_dia_A", "name": "Treino A: Peito, Tríceps e Ombro", "description": "Foco em exercícios de empurrar."},
          {"placeholder_id": "placeholder_dia_B", "name": "Treino B: Costas e Bíceps", "description": "Foco em exercícios de puxar."},
          {"placeholder_id": "placeholder_dia_C", "name": "Treino C: Pernas Completas", "description": "Foco em membros inferiores, incluindo quadríceps, posteriores e panturrilhas."}
        ]
      }
    """;
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }
  
  Future<Map<String, dynamic>> _generateDayStructure(LLMService llm, Map<String, dynamic> dayData, List<WorkoutSession> existingSessions) async {
    final prompt = """
      SYSTEM_PROMPT: Você é um personal trainer. Sua tarefa é detalhar um dia de treino, especificando quais sessões ele contém.
      - Descrição do Dia de Treino: ${jsonEncode(dayData)}
      - Sessões de Treino já existentes: []

      Baseado na descrição do dia (ex: 'Peito, Tríceps e Ombro'), defina as sessões necessárias. Crie sempre sessões novas.
      Retorne ESTRITAMENTE no formato JSON:
      {
        "day_id": "${dayData['placeholder_id']}",
        "sessions_to_create": [
          {"name": "Aquecimento Articular", "description": "Sessão curta de 5-10 minutos para preparar as articulações para o treino principal."},
          {"name": "Treino Principal de Peito, Tríceps e Ombro", "description": "Foco do treino com exercícios compostos e isolados para os grupos musculares alvo."}
        ]
      }
    """;
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }
  
  Future<Map<String, dynamic>> _generateSessionStructure(LLMService llm, Map<String, dynamic> sessionData, List<Exercise> existingExercises) async {
    final prompt = """
      SYSTEM_PROMPT: Você é um personal trainer. Sua tarefa é detalhar uma sessão de treino, especificando quais exercícios ela contém.
      - Descrição da Sessão: ${jsonEncode(sessionData)}
      - Exercícios já existentes: []

      Baseado na descrição da sessão, defina os exercícios necessários. Crie sempre exercícios novos.
      Retorne ESTRITAMENTE no formato JSON:
      {
        "session_id": "${sessionData['name']}",
        "exercises_to_create": [
          {"name": "Supino Reto com Barra", "description": "Deite-se no banco, pegada um pouco mais larga que os ombros, desça a barra até o peito e empurre para cima."},
          {"name": "Desenvolvimento Militar com Halteres", "description": "Sentado ou em pé, eleve os halteres acima da cabeça até a extensão completa dos cotovelos."},
          {"name": "Tríceps na Polia Alta", "description": "Usando uma barra ou corda, estenda os cotovelos para baixo até a contração máxima do tríceps."}
        ]
      }
    """;
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }

  Future<Map<String, dynamic>> _generateExercise(LLMService llm, Map<String, dynamic> exerciseData) async {
    final prompt = """
      SYSTEM_PROMPT: Você é um especialista em cinesiologia. Sua tarefa é detalhar um exercício.
      - Nome e Descrição do Exercício: ${jsonEncode(exerciseData)}
      - Lista de Músculos Válidos: ${jsonEncode(Muscle.values.map((m) => m.name).toList())}

      Com base no nome e descrição, preencha os músculos primários, secundários e as métricas relevantes. Use APENAS os músculos da lista de músculos válidos.
      Retorne ESTRITAMENTE no formato JSON:
      {
        "name": "${exerciseData['name']}",
        "description": "${exerciseData['description']}",
        "primary_muscles": ["pectoralisMajor"],
        "secondary_muscles": ["deltoid", "triceps"],
        "relevant_metrics": ["Peso", "Repetições", "Séries"]
      }
    """;
    final response = await llm.generateResponse(prompt);
    return jsonDecode(response);
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocorreu um Erro'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Plano Personalizado'),
        leading: _currentStep == PlanStep.questions 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = PlanStep.goal))
          : null,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
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
              const SizedBox(height: 24),
              Text(_loadingMessage, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
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
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(question['text'], style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _answers[question['id']],
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn), icon: const Icon(Icons.arrow_back_ios), label: const Text('Anterior')),
                  const Spacer(),
                  if (_currentPage < _questions.length - 1)
                    ElevatedButton.icon(onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn), label: const Text('Próximo'), icon: const Icon(Icons.arrow_forward_ios)),
                  if (_currentPage == _questions.length - 1)
                    ElevatedButton(onPressed: _submitPlan, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Gerar Plano')),
                ],
              ),
            ),
          ],
        );
      case PlanStep.goal:
      default:
        return Padding(
          key: const ValueKey('goal'),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Qual é o seu principal objetivo?', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _goalController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Quero ganhar massa muscular e definir o abdômen, treinando 4x por semana na academia.',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchInitialQuestions,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: const Text('Começar'),
              ),
            ],
          ),
        );
    }
  }
}

// Extensão para converter o UserProfile para JSON, usada nos prompts.
extension UserProfileJson on UserProfile {
  Map<String, dynamic> toJson() => {
    'name': name,
    'height': height,
    'weight': weight,
    'gender': gender,
    'birthDate': birthDate?.toIso8601String(),
  };
}
import 'package:flutter/material.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/exercise_creation_screen.dart';

class WorkoutsHubScreen extends StatefulWidget {
  const WorkoutsHubScreen({super.key});

  @override
  State<WorkoutsHubScreen> createState() => _WorkoutsHubScreenState();
}

class _WorkoutsHubScreenState extends State<WorkoutsHubScreen> {
  // O mapa de valores dos músculos agora começa vazio e é preenchido dinamicamente.
  Map<Muscle, double> _muscleValues = {};

  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para garantir que o context esteja disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMuscleData();
    });
  }

  /// Carrega os exercícios do Hive e calcula a ativação de cada músculo.
  void _loadMuscleData() {
    // 1. Acessa o HiveService via Provider para pegar os exercícios.
    final exercises =
        context.read<HiveService>().getBox<Exercise>('exercises').values.toList();
    final Map<String, double> muscleActivation = {};

    // 2. Calcula um "score" para cada músculo.
    // Músculos primários valem 1.0, secundários valem 0.5.
    for (var exercise in exercises) {
      for (var muscleName in exercise.primaryMuscles) {
        muscleActivation[muscleName] =
            (muscleActivation[muscleName] ?? 0) + 1.0;
      }
      for (var muscleName in exercise.secondaryMuscles) {
        muscleActivation[muscleName] =
            (muscleActivation[muscleName] ?? 0) + 0.5;
      }
    }

    // 3. Normaliza os valores (escala de 0 a 1) para a coloração do mapa.
    // O músculo com o maior score terá o valor 1.0 (cor mais forte).
    double maxActivation = 1.0;
    if (muscleActivation.isNotEmpty) {
      maxActivation = muscleActivation.values.reduce((a, b) => a > b ? a : b);
    }

    final Map<Muscle, double> calculatedValues = {};
    for (var entry in muscleActivation.entries) {
      // Converte o nome do músculo (String) para o enum `Muscle`.
      final muscle = Muscle.values.byNameOrNull(entry.key);
      if (muscle != null) {
        calculatedValues[muscle] = entry.value / maxActivation;
      }
    }

    // 4. Atualiza o estado do widget para redesenhar o mapa com os novos valores.
    setState(() {
      _muscleValues = calculatedValues;
    });
  }

  /// Mostra um painel inferior com os exercícios para o músculo selecionado.
  void _showExercisesForMuscle(Muscle muscle) {
    final exercises = context
        .read<HiveService>()
        .getBox<Exercise>('exercises')
        .values
        .where((ex) =>
            ex.primaryMuscles.contains(muscle.name) ||
            ex.secondaryMuscles.contains(muscle.name))
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Exercícios para ${muscle.name}",
                  style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              if (exercises.isEmpty)
                const Center(
                    child: Text("Nenhum exercício encontrado para este músculo."))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text(exercises[index].name),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Treinos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMuscleData,
            tooltip: 'Atualizar Dados do Mapa',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 500,
              child: MuscleSelector(
                muscleData: _muscleValues,
                onSelect: (muscle, details) {
                  // Ação ao selecionar o músculo agora é interativa.
                  _showExercisesForMuscle(muscle);
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Progresso Geral',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            // TODO: Adicionar gráficos de progresso com fl_chart, lendo o histórico de treinos.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Nova Sessão de Treino'),
                    onPressed: () {
                      // TODO: Navegar para a tela de criação de sessão
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Novo Exercício'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExerciseCreationScreen()),
                      );
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// Extensão para buscar um valor do enum pelo nome (String) de forma segura.
extension MuscleByName on Iterable<Muscle> {
  Muscle? byNameOrNull(String name) {
    for (var value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}
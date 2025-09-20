import 'package:flutter/material.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:provider/provider.dart';

import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/workout_set_entry.dart';
import 'package:fitapp/core/services/benchmarks_service.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/utils/muscle_validation.dart';

import 'package:fitapp/features/4_workouts/presentation/pages/exercise_creation_screen.dart';
import 'package:fitapp/features/4_workouts/presentation/pages/workout_session_creation_screen.dart';
import 'package:fitapp/features/4_workouts/presentation/widgets/progress_charts.dart';

class WorkoutsHubScreen extends StatefulWidget {
  const WorkoutsHubScreen({super.key});
  @override
  State<WorkoutsHubScreen> createState() => _WorkoutsHubScreenState();
}

class _WorkoutsHubScreenState extends State<WorkoutsHubScreen> {
  List<String> _highlightGroups = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMuscleData());
  }

  void _loadMuscleData() {
    final hive = context.read<HiveService>();
    final bench = context.read<BenchmarksService>();
    final profile = hive.getUserProfile();
    final exBox = hive.getBox<Exercise>('exercises');
    final setBox = hive.getBox<WorkoutSetEntry>('workout_set_entries');

    final allExercises = exBox.values.toList();
    final sets = setBox.values.toList();

    final byBench = bench.computeUserBenchmarks(profile, allExercises, sets);

    // Somatório de “força relativa” por grupo (usando APENAS IDs canônicos)
    final score = <String, double>{};
    void acc(List<String> muscles, double pct) {
      if (pct <= 0) return;
      for (final id in muscles) {
        if (isValidGroupId(id)) {
          score[id] = (score[id] ?? 0) + pct;
        }
      }
    }

    acc(['chest', 'anterior_deltoid', 'triceps'],
        byBench['supino_masculino']?.percentile ?? 0);
    acc(['quadriceps', 'glutes', 'lower_back'],
        byBench['agachamento_masculino']?.percentile ?? 0);
    acc(['lower_back', 'glutes', 'hamstrings'],
        byBench['terra_masculino']?.percentile ?? 0);
    acc(['lats', 'biceps'],
        byBench['barra_fixa_masculino']?.percentile ?? 0);

    if (score.isEmpty) {
      setState(() => _highlightGroups = const []);
      return;
    }
    final maxV = score.values.reduce((a, b) => a > b ? a : b);
    final selected = score.entries
        .where((e) => e.value >= 0.5 * maxV)
        .map((e) => e.key)
        .toList();

    setState(() => _highlightGroups = selected);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context
        .watch<HiveService>()
        .getBox<WorkoutSession>('workout_sessions')
        .values
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Treinos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMuscleData)
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 480,
              child: MusclePickerMap(
                map: Maps.BODY,
                isEditing: false,
                initialSelectedGroups: _highlightGroups, // IDs canônicos
                onChanged: (_) {}, // somente visual
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: ProgressCharts(),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sessões de Treino',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkoutSessionCreationScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Sessão'),
                  )
                ],
              ),
            ),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nenhuma sessão criada.'),
              )
            else
              ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) => ListTile(
                  title: Text(sessions[i].name),
                  subtitle: Text(sessions[i].description),
                ),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: sessions.length,
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Novo Exercício'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExerciseCreationScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

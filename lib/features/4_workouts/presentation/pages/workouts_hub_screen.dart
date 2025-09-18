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

  // PT -> ids aceitos pelo muscle_selector (snake_case)
  String? _ptToGroupId(String pt) {
    switch (pt) {
      case 'peitoral':
        return 'chest';
      case 'deltoide_anterior':
      case 'deltoide anterior':
        return 'anterior_deltoid';
      case 'tríceps':
      case 'triceps':
        return 'triceps';
      case 'quadríceps':
      case 'quadriceps':
        return 'quadriceps';
      case 'glúteos':
      case 'gluteos':
        return 'glutes';
      case 'lombar':
        return 'lower_back';
      case 'posterior_coxa':
      case 'posterior coxa':
        return 'hamstrings';
      case 'dorsal':
        return 'lats';
      case 'bíceps':
      case 'biceps':
        return 'biceps';
      default:
        return null;
    }
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

    // Somatório de “força relativa” por grupo
    final score = <String, double>{};
    void acc(List<String> musclesPt, double pct) {
      if (pct <= 0) return;
      for (final pt in musclesPt) {
        final id = _ptToGroupId(pt);
        if (id != null && isValidGroupId(id)) {
          score[id] = (score[id] ?? 0) + pct;
        }
      }
    }

    acc(['peitoral', 'deltoide_anterior', 'tríceps'],
        byBench['supino_masculino']?.percentile ?? 0);
    acc(['quadríceps', 'glúteos', 'lombar'],
        byBench['agachamento_masculino']?.percentile ?? 0);
    acc(['lombar', 'glúteos', 'posterior_coxa'],
        byBench['terra_masculino']?.percentile ?? 0);
    acc(['dorsal', 'bíceps'],
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
                initialSelectedGroups: _highlightGroups,
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
                            builder: (_) =>
                                const WorkoutSessionCreationScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Sessão'),
                  )
                ],
              ),
            ),
            if (sessions.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Nenhuma sessão criada.'))
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
                              builder: (_) =>
                                  const ExerciseCreationScreen())),
                    ),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_session.dart';
import 'package:seu_app/core/models/workout_set_entry.dart';
import 'package:seu_app/core/services/benchmarks_service.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/exercise_creation_screen.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/workout_session_creation_screen.dart';
import 'package:seu_app/features/4_workouts/presentation/widgets/progress_charts.dart';

class WorkoutsHubScreen extends StatefulWidget {
  const WorkoutsHubScreen({super.key});
  @override
  State<WorkoutsHubScreen> createState() => _WorkoutsHubScreenState();
}

class _WorkoutsHubScreenState extends State<WorkoutsHubScreen> {
  Map<Muscle, double> _muscleValues = {};

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

    // Calcula melhor desempenho por categoria de benchmark
    final byBench = bench.computeUserBenchmarks(profile, allExercises, sets);

    // Mapeia benchmark->músculos e aplica percentil 0..1
    final muscleScore = <String, double>{};
    void acc(List<String> muscles, double pct) {
      for (final m in muscles) {
        muscleScore[m] = (muscleScore[m] ?? 0) + pct;
      }
    }

    acc(['peitoral', 'deltoide_anterior', 'tríceps'], byBench['supino_masculino']?.percentile ?? 0);
    acc(['quadríceps', 'glúteos', 'lombar'], byBench['agachamento_masculino']?.percentile ?? 0);
    acc(['lombar', 'glúteos', 'posterior_coxa'], byBench['terra_masculino']?.percentile ?? 0);
    acc(['dorsal', 'bíceps'], byBench['barra_fixa_masculino']?.percentile ?? 0);

    // Normaliza 0..1
    double maxA = 1.0;
    if (muscleScore.isNotEmpty) {
      maxA = muscleScore.values.reduce((a, b) => a > b ? a : b);
    }
    final values = <Muscle, double>{};
    for (final e in muscleScore.entries) {
      final muscle = Muscle.values.byNameOrNull(e.key);
      if (muscle != null) values[muscle] = (e.value / maxA).clamp(0.0, 1.0);
    }

    setState(() => _muscleValues = values);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<HiveService>().getBox<WorkoutSession>('workout_sessions').values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Treinos'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMuscleData)],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 480, child: MuscleSelector(muscleData: _muscleValues, onSelect: (m, _) {})),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: const ProgressCharts(),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Sessões de Treino', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutSessionCreationScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Sessão'),
                )
              ]),
            ),
            if (sessions.isEmpty)
              const Padding(padding: EdgeInsets.all(8), child: Text('Nenhuma sessão criada.'))
            else
              ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) => ListTile(title: Text(sessions[i].name), subtitle: Text(sessions[i].description)),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: sessions.length,
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Criar Novo Exercício'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseCreationScreen())),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

extension MuscleByName on Iterable<Muscle> {
  Muscle? byNameOrNull(String name) {
    for (var v in this) {
      if (v.name == name) return v;
    }
    return null;
  }
}

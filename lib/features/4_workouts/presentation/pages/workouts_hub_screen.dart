import 'package:flutter/material.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_session.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/exercise_creation_screen.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/workout_session_creation_screen.dart';

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
    final exercises = context.read<HiveService>().getBox<Exercise>('exercises').values.toList();
    final Map<String, double> muscleActivation = {};
    for (var ex in exercises) {
      for (var m in ex.primaryMuscles) { muscleActivation[m] = (muscleActivation[m] ?? 0) + 1.0; }
      for (var m in ex.secondaryMuscles) { muscleActivation[m] = (muscleActivation[m] ?? 0) + 0.5; }
    }
    double maxA = 1.0;
    if (muscleActivation.isNotEmpty) {
      maxA = muscleActivation.values.reduce((a, b) => a > b ? a : b);
    }
    final Map<Muscle, double> values = {};
    for (var e in muscleActivation.entries) {
      final muscle = Muscle.values.byNameOrNull(e.key);
      if (muscle != null) values[muscle] = e.value / maxA;
    }
    setState(() => _muscleValues = values);
  }

  void _showExercisesForMuscle(Muscle muscle) {
    final exercises = context
        .read<HiveService>()
        .getBox<Exercise>('exercises')
        .values
        .where((ex) => ex.primaryMuscles.contains(muscle.name) || ex.secondaryMuscles.contains(muscle.name))
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Exercícios para ${muscle.name}", style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            if (exercises.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text("Nenhum exercício encontrado.")),
            if (exercises.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, i) => ListTile(title: Text(exercises[i].name)),
                ),
              ),
          ]),
        ),
      ),
    );
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
            SizedBox(
              height: 480,
              child: MuscleSelector(
                muscleData: _muscleValues,
                onSelect: (muscle, details) => _showExercisesForMuscle(muscle),
              ),
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
              const Padding(padding: EdgeInsets.all(8), child: Text('Nenhuma sessão criada.')),
            if (sessions.isNotEmpty)
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
    for (var v in this) { if (v.name == name) return v; }
    return null;
  }
}

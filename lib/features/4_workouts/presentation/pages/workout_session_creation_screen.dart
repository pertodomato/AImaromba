import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:hive/hive.dart';
class WorkoutSessionCreationScreen extends StatefulWidget {
  const WorkoutSessionCreationScreen({super.key});
  @override
  State<WorkoutSessionCreationScreen> createState() => _WorkoutSessionCreationScreenState();
}

class _WorkoutSessionCreationScreenState extends State<WorkoutSessionCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final Set<String> _selectedExerciseIds = {};

  @override
  Widget build(BuildContext context) {
    final hive = context.watch<HiveService>();
    final exercises = hive.getBox<Exercise>('exercises').values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Sessão de Treino'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Nome'), validator: (v) => (v==null||v.isEmpty) ? 'Obrigatório' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _descCtl, decoration: const InputDecoration(labelText: 'Descrição'), maxLines: 3),
            const SizedBox(height: 16),
            Text('Selecione exercícios', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...exercises.map((e) => CheckboxListTile(
                  title: Text(e.name),
                  value: _selectedExerciseIds.contains(e.id),
                  onChanged: (sel) => setState(() {
                    if (sel == true) { _selectedExerciseIds.add(e.id); } else { _selectedExerciseIds.remove(e.id); }
                  }),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hive = context.read<HiveService>();
    final exBox = hive.getBox<Exercise>('exercises');
    final selected = exBox.values.where((ex) => _selectedExerciseIds.contains(ex.id)).toList();
    final session = WorkoutSession(
      id: const Uuid().v4(),
      name: _nameCtl.text.trim(),
      description: _descCtl.text.trim(),
      exercises: HiveList(exBox)..addAll(selected),
    );
    await hive.getBox<WorkoutSession>('workout_sessions').add(session);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão criada!')));
    }
  }
}

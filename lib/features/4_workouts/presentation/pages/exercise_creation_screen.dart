import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/utils/muscle_validation.dart';

class ExerciseCreationScreen extends StatefulWidget {
  const ExerciseCreationScreen({super.key});

  @override
  State<ExerciseCreationScreen> createState() => _ExerciseCreationScreenState();
}

class _ExerciseCreationScreenState extends State<ExerciseCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // nomes exatamente como definidos no muscle_validation.dart
  late final List<String> _allMuscles = kValidGroupIds.toList();

  // métricas padrão
  static const List<String> _allMetrics = <String>[
    'Peso',
    'Repetições',
    'Distância',
    'Tempo',
    'Séries',
  ];

  final Set<String> _primaryMuscles = {};
  final Set<String> _secondaryMuscles = {};
  final Set<String> _relevantMetrics = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _finalizeMuscles() {
    // mantém apenas válidos e remove interseção (secundários ≠ primários)
    final prim = _primaryMuscles.where(isValidMuscleName).toSet();
    final sec = _secondaryMuscles.where(isValidMuscleName).toSet()..removeAll(prim);
    _primaryMuscles
      ..clear()
      ..addAll(prim);
    _secondaryMuscles
      ..clear()
      ..addAll(sec);
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;

    if (_primaryMuscles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos 1 músculo primário.')),
      );
      return;
    }
    if (_relevantMetrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos 1 métrica relevante.')),
      );
      return;
    }

    _finalizeMuscles();

    final newExercise = Exercise(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      primaryMuscles: _primaryMuscles.toList(),
      secondaryMuscles: _secondaryMuscles.toList(),
      relevantMetrics: _relevantMetrics.toList(),
    );

    final hive = context.read<HiveService>();
    await hive.getBox<Exercise>('exercises').add(newExercise);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newExercise.name} foi salvo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Exercício'),
        actions: [
          IconButton(onPressed: _saveExercise, icon: const Icon(Icons.save)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do Exercício'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição/Instruções'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('Músculos Primários', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMuscleSelector(_primaryMuscles),
            const SizedBox(height: 24),
            Text('Músculos Secundários', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMuscleSelector(_secondaryMuscles),
            const SizedBox(height: 24),
            Text('Métricas Relevantes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMetricsSelector(),
          ]),
        ),
      ),
    );
  }

  Widget _buildMuscleSelector(Set<String> selectedMuscles) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _allMuscles.map((muscle) {
        final isSelected = selectedMuscles.contains(muscle);
        return FilterChip(
          label: Text(muscle, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                selectedMuscles.add(muscle);
              } else {
                selectedMuscles.remove(muscle);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildMetricsSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _allMetrics.map((metric) {
        final isSelected = _relevantMetrics.contains(metric);
        return FilterChip(
          label: Text(metric),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                _relevantMetrics.add(metric);
              } else {
                _relevantMetrics.remove(metric);
              }
            });
          },
        );
      }).toList(),
    );
  }
}

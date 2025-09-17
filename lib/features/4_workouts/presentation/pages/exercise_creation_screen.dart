import 'package:flutter/material.dart';
import 'package.provider/provider.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:uuid/uuid.dart';

class ExerciseCreationScreen extends StatefulWidget {
  const ExerciseCreationScreen({super.key});

  @override
  State<ExerciseCreationScreen> createState() => _ExerciseCreationScreenState();
}

class _ExerciseCreationScreenState extends State<ExerciseCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Lista completa de músculos para seleção
  final List<String> _allMuscles = Muscle.values.map((m) => m.name).toList();
  
  Set<String> _primaryMuscles = {};
  Set<String> _secondaryMuscles = {};
  Set<String> _relevantMetrics = {};

  void _saveExercise() async {
    if (_formKey.currentState!.validate()) {
      final newExercise = Exercise(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text,
        primaryMuscles: _primaryMuscles.toList(),
        secondaryMuscles: _secondaryMuscles.toList(),
        relevantMetrics: _relevantMetrics.toList(),
      );

      final hive = context.read<HiveService>();
      await hive.getBox<Exercise>('exercises').add(newExercise);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newExercise.name} foi salvo!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Exercício'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveExercise)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome do Exercício'),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição/Instruções'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text('Músculos Primários', style: Theme.of(context).textTheme.titleMedium),
              _buildMuscleSelector(_primaryMuscles),
              const SizedBox(height: 24),
              Text('Músculos Secundários', style: Theme.of(context).textTheme.titleMedium),
              _buildMuscleSelector(_secondaryMuscles),
              const SizedBox(height: 24),
              Text('Métricas Relevantes', style: Theme.of(context).textTheme.titleMedium),
              _buildMetricsSelector(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMuscleSelector(Set<String> selectedMuscles) {
    return Wrap(
      spacing: 8.0,
      children: _allMuscles.map((muscle) {
        final isSelected = selectedMuscles.contains(muscle);
        return FilterChip(
          label: Text(muscle, style: TextStyle(fontSize: 12)),
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
    final allMetrics = ['Peso', 'Repetições', 'Distância', 'Tempo', 'Séries'];
    return Wrap(
      spacing: 8.0,
      children: allMetrics.map((metric) {
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
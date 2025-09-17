import 'package:flutter/material.dart';

// Modelo simples para os dados de um set
class ExerciseSet {
  int setNumber;
  String? previousMetrics; // Ex: "80kg x 10 reps"
  TextEditingController weightController = TextEditingController();
  TextEditingController repsController = TextEditingController();
  bool isDone = false;

  ExerciseSet({required this.setNumber, this.previousMetrics});
}

class WorkoutInProgressScreen extends StatefulWidget {
  const WorkoutInProgressScreen({super.key});

  @override
  State<WorkoutInProgressScreen> createState() => _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen> {
  // Dados de exemplo
  final List<Map<String, dynamic>> exercises = [
    {
      'name': 'Supino Reto',
      'sets': [
        ExerciseSet(setNumber: 1, previousMetrics: "80kg x 8"),
        ExerciseSet(setNumber: 2, previousMetrics: "80kg x 8"),
        ExerciseSet(setNumber: 3, previousMetrics: "80kg x 6"),
      ]
    },
    {
      'name': 'Flexão',
      'sets': [
        ExerciseSet(setNumber: 1, previousMetrics: "15 reps"),
        ExerciseSet(setNumber: 2, previousMetrics: "12 reps"),
        ExerciseSet(setNumber: 3, previousMetrics: "10 reps"),
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino de Peito'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 0.3), // Progresso do treino
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise['name'], style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  ..._buildSetRows(exercise['sets']),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            // Lógica para finalizar o treino
            Navigator.of(context).pop();
          },
          child: const Text('Finalizar Treino', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  List<Widget> _buildSetRows(List<ExerciseSet> sets) {
    return sets.map((s) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: s.isDone ? Colors.green : Colors.grey[700],
              child: Text(s.setNumber.toString(), style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: s.weightController,
                decoration: InputDecoration(
                  labelText: 'Peso (kg)',
                  hintText: s.previousMetrics?.split('x')[0] ?? '',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: s.repsController,
                decoration: InputDecoration(
                  labelText: 'Reps',
                  hintText: s.previousMetrics?.split('x').length == 2 ? s.previousMetrics?.split('x')[1] : '',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(s.isDone ? Icons.check_box : Icons.check_box_outline_blank),
              onPressed: () {
                setState(() {
                  s.isDone = !s.isDone;
                });
              },
            ),
          ],
        ),
      );
    }).toList();
  }
}
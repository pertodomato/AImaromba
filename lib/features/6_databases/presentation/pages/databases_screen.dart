import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:hive/hive.dart';

class DatabasesScreen extends StatelessWidget {
  const DatabasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = context.read<HiveService>();
    final boxes = <String, Box>{
      'user_profile': hive.getBox<UserProfile>('user_profile'),
      'exercises': hive.getBox<Exercise>('exercises'),
      'workout_sessions': hive.getBox<WorkoutSession>('workout_sessions'),
      'workout_days': hive.getBox<WorkoutDay>('workout_days'),
      'workout_routines': hive.getBox<WorkoutRoutine>('workout_routines'),
      'meal_entries': hive.getBox<MealEntry>('meal_entries'),
      'meals': hive.getBox<Meal>('meals'),
      'weight_entries': hive.getBox<WeightEntry>('weight_entries'),
      'diet_days': hive.getBox<DietDay>('diet_days'),
      'diet_routines': hive.getBox<DietRoutine>('diet_routines'),
      'workout_set_entries': hive.getBox<WorkoutSetEntry>('workout_set_entries'),
      'workout_session_logs': hive.getBox<WorkoutSessionLog>('workout_session_logs'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Bancos de Dados')),
      body: ListView(
        children: boxes.entries.map((e) {
          return Card(
            child: ListTile(
              title: Text(e.key),
              subtitle: Text('Registros: ${e.value.length}'),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _BoxViewer(title: e.key, box: e.value),
              )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BoxViewer extends StatelessWidget {
  final String title;
  final Box box;
  const _BoxViewer({required this.title, required this.box});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(box.length, (i) => box.getAt(i));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => ListTile(
          title: Text(items[i].toString()),
        ),
      ),
    );
  }
}

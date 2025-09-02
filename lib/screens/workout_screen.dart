import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/util.dart';
import '../widgets/app_drawer.dart'; // + import

class WorkoutScreen extends StatefulWidget {
  final String blockId;
  const WorkoutScreen({super.key, required this.blockId});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late Map block; late List items;
  final Map<String, List<Map<String, dynamic>>> results = {};

  @override
  void initState() {
    super.initState();
    block = Hive.box('blocks').get(widget.blockId);
    items = List.from(block['exercises']);
    for (final it in items) {
      final sets = it['sets'] as int? ?? 3;
      results[it['exerciseId']] = List.generate(sets, (_)=> {'weight': null,'reps': null,'distance': null,'time': null});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(block['name'])),
      drawer: const AppNavDrawer(), // <-- ADICIONE
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i){
          final it = items[i];
          final ex = Hive.box('exercises').get(it['exerciseId']);
          final sets = results[it['exerciseId']]!;
          final metrics = Map<String, dynamic>.from(ex['metrics']);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (int s=0; s<sets.length; s++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text('S${s+1}'),
                      const SizedBox(width: 8),
                      if (metrics['weight'] == true) SizedBox(
                        width: 80,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Peso'),
                          keyboardType: TextInputType.number,
                          onChanged: (v)=> sets[s]['weight'] = double.tryParse(v),
                        ),
                      ),
                      if (metrics['reps'] == true) const SizedBox(width: 8),
                      if (metrics['reps'] == true) SizedBox(
                        width: 70,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Reps'),
                          keyboardType: TextInputType.number,
                          onChanged: (v)=> sets[s]['reps'] = int.tryParse(v),
                        ),
                      ),
                      if (metrics['distance'] == true) const SizedBox(width: 8),
                      if (metrics['distance'] == true) SizedBox(
                        width: 90,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Dist (km)'),
                          keyboardType: TextInputType.number,
                          onChanged: (v)=> sets[s]['distance'] = double.tryParse(v),
                        ),
                      ),
                      if (metrics['time'] == true) const SizedBox(width: 8),
                      if (metrics['time'] == true) SizedBox(
                        width: 90,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Min'),
                          keyboardType: TextInputType.number,
                          onChanged: (v)=> sets[s]['time'] = double.tryParse(v),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finish,
        icon: const Icon(Icons.check),
        label: const Text('Finalizar'),
      ),
    );
  }

  Future<void> _finish() async {
    final exBox = Hive.box('exercises');
    final profile = Hive.box('profile');

    double totalCalories = 0;
    int totalXP = 0;
    final mv = Map<String, double>.from(profile.get('muscleVolumeScore', defaultValue: <String, double>{}));

    for (final it in items) {
      final ex = exBox.get(it['exerciseId']);
      final sets = results[it['exerciseId']]!;
      final metrics = Map<String, dynamic>.from(ex['metrics']);
      final met = (ex['met'] as num?)?.toDouble() ?? 6.0;

      // Estimativa de tempo se não informado (força): 40s por série + descanso informado
      double minutes = 0;
      for (final s in sets) {
        if (metrics['time'] == true && s['time'] != null) {
          minutes += (s['time'] as num).toDouble();
        } else {
          final rest = (it['restSec'] as num?)?.toDouble() ?? 60.0;
          minutes += (40.0 + rest) / 60.0;
        }
      }

      final bw = (profile.get('weight', defaultValue: 75.0) as num).toDouble();
      totalCalories += kcalFromMET(met: met, bodyWeightKg: bw, minutes: minutes);

      // XP simples: soma de reps (ou minutos*5 para cardio)
      for (final s in sets) {
        if (metrics['reps'] == true && s['reps'] != null) {
          totalXP += (s['reps'] as int);
        } else if (metrics['time'] == true && s['time'] != null) {
          totalXP += ((s['time'] as num).toDouble() * 5).round();
        }
      }

      // Atualiza melhores marcas (1RM / barra fixa reps)
      for (final s in sets) {
        if (ex['id'] == 'bench_bar' && s['weight'] != null && s['reps'] != null) {
          final e = estimate1RM((s['weight'] as num).toDouble(), (s['reps'] as int));
          final cur = (profile.get('best1RM_supino') as num?)?.toDouble() ?? 0;
          if (e > cur) profile.put('best1RM_supino', e);
        }
        if (ex['id'] == 'squat_bar' && s['weight'] != null && s['reps'] != null) {
          final e = estimate1RM((s['weight'] as num).toDouble(), (s['reps'] as int));
          final cur = (profile.get('best1RM_agachamento') as num?)?.toDouble() ?? 0;
          if (e > cur) profile.put('best1RM_agachamento', e);
        }
        if (ex['id'] == 'deadlift_bar' && s['weight'] != null && s['reps'] != null) {
          final e = estimate1RM((s['weight'] as num).toDouble(), (s['reps'] as int));
          final cur = (profile.get('best1RM_terra') as num?)?.toDouble() ?? 0;
          if (e > cur) profile.put('best1RM_terra', e);
        }
        if (ex['id'] == 'pullup' && s['reps'] != null) {
          final reps = (s['reps'] as int).toDouble();
          final cur = (profile.get('bestReps_barra_fixa') as num?)?.toDouble() ?? 0;
          if (reps > cur) profile.put('bestReps_barra_fixa', reps);
        }
      }

      // Volume por músculos (simples)
      for (final m in (ex['primary'] as List)) {
        mv[m] = (mv[m] ?? 0) + (results[it['exerciseId']]!.length).toDouble() * 1.0;
      }
    }

    // Salva sessão
    final sessions = Hive.box('sessions');
    final date = DateTime.now().toIso8601String().substring(0,10);
    sessions.add({
      'date': date,
      'blockId': block['id'],
      'name': block['name'],
      'items': results,
      'calories': totalCalories,
      'xp': totalXP,
    });

    // Atualiza XP e músculos
    final curXP = (profile.get('xp', defaultValue: 0) as num).toInt();
    profile.put('xp', curXP + totalXP);
    profile.put('muscleVolumeScore', mv);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sessão salva! ~ ${totalCalories.toStringAsFixed(0)} kcal, +$totalXP XP')));
      Navigator.pop(context);
    }
  }
}

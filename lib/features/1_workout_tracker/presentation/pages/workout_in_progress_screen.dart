import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_session.dart';
import 'package:seu_app/core/models/workout_session_log.dart';
import 'package:seu_app/core/models/workout_set_entry.dart';

class WorkoutInProgressScreen extends StatefulWidget {
  const WorkoutInProgressScreen({super.key, this.session});
  final WorkoutSession? session; // opcional: pode vir da Home

  @override
  State<WorkoutInProgressScreen> createState() => _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen> {
  late WorkoutSession _session;
  late WorkoutSessionLog _log;

  final Map<String, List<_SetRowState>> _controllersByExercise = {}; // exerciseId -> set rows
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final hive = context.read<HiveService>();
    _session = widget.session ?? hive.getBox<WorkoutSession>('workout_sessions').values.first;
    _log = WorkoutSessionLog(
      id: _uuid.v4(),
      workoutSessionId: _session.id,
      startedAt: DateTime.now(),
    );
    hive.getBox<WorkoutSessionLog>('workout_session_logs').add(_log);

    // cria 3 sets por exercício por padrão
    for (final ex in _session.exercises) {
      final prev = _getLastSetForExercise(ex.id);
      _controllersByExercise[ex.id] = List.generate(
        3,
        (i) => _SetRowState(
          setNumber: i + 1,
          previous: prev,
          metrics: _defaultMetricsFor(ex),
        ),
      );
    }
  }

  WorkoutSetEntry? _getLastSetForExercise(String exerciseId) {
    final box = context.read<HiveService>().getBox<WorkoutSetEntry>('workout_set_entries');
    final all = box.values.where((e) => e.exerciseId == exerciseId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.isEmpty ? null : all.first;
  }

  List<String> _defaultMetricsFor(Exercise ex) {
    // usa métricas relevantes do Exercise
    final List<String> m = [];
    for (final k in ex.relevantMetrics) {
      if (['Peso', 'Repetições', 'Séries', 'Distância', 'Tempo'].contains(k)) m.add(k);
    }
    if (!m.contains('Séries')) m.add('Séries');
    return m;
  }

  String _formatPrev(WorkoutSetEntry? e) {
    if (e == null) return 'Sem histórico';
    final parts = e.metrics.entries.map((kv) => '${kv.key}:${kv.value.toStringAsFixed(0)}').join(' ');
    return 'Último: $parts';
    }

  Future<void> _finish() async {
    final hive = context.read<HiveService>();
    final setBox = hive.getBox<WorkoutSetEntry>('workout_set_entries');

    for (final ex in _session.exercises) {
      final rows = _controllersByExercise[ex.id]!;
      for (final r in rows) {
        if (!r.isDone) continue;
        final metrics = <String, double>{};
        for (final m in r.metrics) {
          final v = double.tryParse(r.controllers[m]?.text ?? '');
          if (v != null && v > 0) metrics[m] = v;
        }
        if (metrics.isEmpty) continue;

        final entry = WorkoutSetEntry(
          id: _uuid.v4(),
          sessionLogId: _log.id,
          exerciseId: ex.id,
          setIndex: r.setNumber,
          metrics: metrics,
          timestamp: DateTime.now(),
        );
        await setBox.add(entry);
      }
    }

    final logBox = hive.getBox<WorkoutSessionLog>('workout_session_logs');
    _log.endedAt = DateTime.now();
    await _log.save();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino finalizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 0.3),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _session.exercises.length,
        itemBuilder: (context, index) {
          final exercise = _session.exercises[index];
          final rows = _controllersByExercise[exercise.id]!;
          final prev = _getLastSetForExercise(exercise.id);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exercise.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(_formatPrev(prev), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                ...rows.map((r) => _SetRow(exerciseId: exercise.id, state: r)),
              ]),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _finish,
          child: const Text('Finalizar Treino', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _SetRowState {
  _SetRowState({required this.setNumber, required this.metrics, this.previous}) {
    for (final m in metrics) {
      controllers[m] = TextEditingController();
    }
  }
  final int setNumber;
  final List<String> metrics;
  final Map<String, TextEditingController> controllers = {};
  bool isDone = false;
  final WorkoutSetEntry? previous;
}

class _SetRow extends StatefulWidget {
  const _SetRow({required this.exerciseId, required this.state});
  final String exerciseId;
  final _SetRowState state;

  @override
  State<_SetRow> createState() => _SetRowStateful();
}

class _SetRowStateful extends State<_SetRow> {
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: s.isDone ? Colors.green : Colors.grey[700],
          child: Text(s.setNumber.toString(), style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.metrics.map((m) {
              return SizedBox(
                width: 110,
                child: TextFormField(
                  controller: s.controllers[m],
                  decoration: InputDecoration(
                    labelText: m,
                    hintText: _hintFor(m, s.previous),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(s.isDone ? Icons.check_box : Icons.check_box_outline_blank),
          onPressed: () => setState(() => s.isDone = !s.isDone),
        ),
      ]),
    );
  }

  String _hintFor(String metric, WorkoutSetEntry? prev) {
    if (prev == null) return '';
    final v = prev.metrics[metric];
    if (v == null) return '';
    return v.toStringAsFixed(0);
  }
}

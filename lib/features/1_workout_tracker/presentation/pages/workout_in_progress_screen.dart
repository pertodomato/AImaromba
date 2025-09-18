import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/workout_session_log.dart';
import 'package:fitapp/core/models/workout_set_entry.dart';

class WorkoutInProgressScreen extends StatefulWidget {
  const WorkoutInProgressScreen({super.key, this.session});
  final WorkoutSession? session;

  @override
  State<WorkoutInProgressScreen> createState() => _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen> {
  late WorkoutSession _session;
  late WorkoutSessionLog _log;

  final Map<String, List<_SetRowState>> _controllersByExercise = {};
  final _uuid = const Uuid();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final hive = context.read<HiveService>();
    final sessions = hive.getBox<WorkoutSession>('workout_sessions').values.toList();

    final resolved = widget.session ?? (sessions.isNotEmpty ? sessions.first : null);
    if (resolved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma sessão de treino encontrada.')),
        );
      });
      return;
    }

    _session = resolved;
    _ready = true;

    _log = WorkoutSessionLog(
      id: _uuid.v4(),
      workoutSessionId: _session.id,
      startedAt: DateTime.now(),
    );
    hive.getBox<WorkoutSessionLog>('workout_session_logs').add(_log);

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

  @override
  void dispose() {
    for (final list in _controllersByExercise.values) {
      for (final r in list) {
        for (final c in r.controllers.values) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  WorkoutSetEntry? _getLastSetForExercise(String exerciseId) {
    final box = context.read<HiveService>().getBox<WorkoutSetEntry>('workout_set_entries');
    final all = box.values.where((e) => e.exerciseId == exerciseId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.isEmpty ? null : all.first;
  }

  List<String> _defaultMetricsFor(Exercise ex) {
    final List<String> m = [];
    for (final k in ex.relevantMetrics) {
      if (['Peso', 'Repetições', 'Séries', 'Distância', 'Tempo'].contains(k)) m.add(k);
    }
    if (!m.contains('Séries')) m.add('Séries');
    return m;
  }

  String _formatPrev(WorkoutSetEntry? e) {
    if (e == null || e.metrics.isEmpty) return 'Sem histórico';
    final parts = e.metrics.entries.map((kv) => '${kv.key}:${kv.value.toStringAsFixed(0)}').join(' ');
    return 'Último: $parts';
  }

  double get _progress {
    int total = 0, done = 0;
    for (final rows in _controllersByExercise.values) {
      total += rows.length;
      done += rows.where((r) => r.isDone).length;
    }
    return total == 0 ? 0 : done / total;
  }

  void _notifyParent() => setState(() {});

  Future<void> _finish() async {
    final hive = context.read<HiveService>();
    final setBox = hive.getBox<WorkoutSetEntry>('workout_set_entries');

    for (final ex in _session.exercises) {
      final rows = _controllersByExercise[ex.id] ?? const [];
      for (final r in rows) {
        if (!r.isDone) continue;
        final metrics = <String, double>{};
        for (final m in r.metrics) {
          final raw = (r.controllers[m]?.text ?? '').replaceAll(',', '.');
          final v = double.tryParse(raw);
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

    _log.endedAt = DateTime.now();
    await _log.save();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino finalizado')));
    }
  }

  Future<void> _chooseEquivalentExercise(int index, Exercise current) async {
    final hive = context.read<HiveService>();
    final all = hive.getBox<Exercise>('exercises').values.toList();

    bool sameGroup(Exercise a, Exercise b) =>
        a.primaryMuscles.toSet().intersection(b.primaryMuscles.toSet()).isNotEmpty;

    final options = all.where((e) => e.id != current.id && sameGroup(e, current)).toList();
    if (options.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem equivalentes cadastrados.')));
      }
      return;
    }

    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Trocar por')),
            for (final e in options)
              ListTile(
                title: Text(e.name),
                subtitle: Text(e.primaryMuscles.join(', ')),
                onTap: () => Navigator.pop(context, e),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;

    setState(() {
      final oldId = current.id;
      final newId = picked.id;
      _session.exercises[index] = picked; // HiveList<Exercise>
      final state = _controllersByExercise.remove(oldId) ?? [];
      _controllersByExercise[newId] = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: _progress),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _session.exercises.length,
        itemBuilder: (context, index) {
          final exercise = _session.exercises[index];
          final rows = _controllersByExercise[exercise.id] ?? const <_SetRowState>[];
          final prev = _getLastSetForExercise(exercise.id);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(child: Text(exercise.name, style: Theme.of(context).textTheme.titleSmall)),
                    TextButton.icon(
                      onPressed: () => _chooseEquivalentExercise(index, exercise),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Trocar'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_formatPrev(prev), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                ...rows.map((r) => _SetRow(exerciseId: exercise.id, state: r, onChanged: _notifyParent)),
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
  const _SetRow({required this.exerciseId, required this.state, required this.onChanged});
  final String exerciseId;
  final _SetRowState state;
  final VoidCallback onChanged;

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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(s.isDone ? Icons.check_box : Icons.check_box_outline_blank),
          onPressed: () {
            setState(() => s.isDone = !s.isDone);
            widget.onChanged();
          },
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

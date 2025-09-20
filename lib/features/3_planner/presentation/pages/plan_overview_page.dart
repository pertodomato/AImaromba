// lib/features/3_planner/presentation/pages/plan_overview_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:fitapp/core/services/hive_service.dart';

import 'package:fitapp/core/models/workout_routine.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/workout_session.dart';
import 'package:fitapp/core/models/exercise.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';

import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_routine_schedule.dart';
import 'package:fitapp/core/models/diet_block.dart';
import 'package:fitapp/core/models/diet_day.dart';

import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';
import 'planner_screen.dart';

class PlanOverviewPage extends StatefulWidget {
  const PlanOverviewPage({super.key});

  @override
  State<PlanOverviewPage> createState() => _PlanOverviewPageState();
}

class _PlanOverviewPageState extends State<PlanOverviewPage> {
  WorkoutRoutine? _wr;
  WorkoutRoutineSchedule? _ws;
  late Box<WorkoutBlock> _wBlockBox;
  late Box<WorkoutDay> _wDayBox;
  late Box<WorkoutSession> _wSessBox;
  late Box<Exercise> _wExBox;

  DietRoutine? _dr;
  DietRoutineSchedule? _ds;
  late Box<DietBlock> _dBlockBox;
  late Box<DietDay> _dDayBox;

  @override
  void initState() {
    super.initState();
    final hive = context.read<HiveService>();

    // Workout boxes
    final wRoutineBox = hive.getBox<WorkoutRoutine>('workout_routines');
    final wScheduleBox = hive.getBox<WorkoutRoutineSchedule>('routine_schedules');
    _wBlockBox = hive.getBox<WorkoutBlock>('workout_blocks');
    _wDayBox = hive.getBox<WorkoutDay>('workout_days');
    _wSessBox = hive.getBox<WorkoutSession>('workout_sessions');
    _wExBox = hive.getBox<Exercise>('exercises');

    _wr = wRoutineBox.values.isEmpty ? null : wRoutineBox.values.first;
    if (_wr != null) {
      final matches = wScheduleBox.values
          .where((s) => s.routineSlug == _wr!.id || s.routineSlug == toSlug(_wr!.name))
          .toList();
      _ws = matches.isEmpty ? null : matches.first;
    }

    // Diet boxes
    final dRoutineBox = hive.getBox<DietRoutine>('diet_routines');
    final dScheduleBox =
        hive.getBox<DietRoutineSchedule>('diet_routine_schedules');
    _dBlockBox = hive.getBox<DietBlock>('diet_blocks');
    _dDayBox = hive.getBox<DietDay>('diet_days');

    _dr = dRoutineBox.values.isEmpty ? null : dRoutineBox.values.first;
    if (_dr != null) {
      final matches = dScheduleBox.values
          .where((s) => s.routineSlug == _dr!.id || s.routineSlug == toSlug(_dr!.name))
          .toList();
      _ds = matches.isEmpty ? null : matches.first;
    }

    // Logs
    // ignore: avoid_print
    print('PlanOverview init: '
        'wr=${_wr?.name} ws=${_ws?.routineSlug} '
        'dr=${_dr?.name} ds=${_ds?.routineSlug}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão do Plano Gerado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Ver no Calendário',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PlannerScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildWorkoutSection(),
          const SizedBox(height: 12),
          _buildDietSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ---------- WORKOUT ----------
  Widget _buildWorkoutSection() {
    if (_wr == null) {
      return const Card(
        child: ListTile(title: Text('Nenhuma rotina de treino encontrada.')),
      );
    }

    final blockSlugs = _ws?.blockSequence ?? const <String>[];
    final blocks = <WorkoutBlock>[];
    for (final slug in blockSlugs) {
      final match = _wBlockBox.values.where((b) => b.slug == slug).toList();
      if (match.isNotEmpty) blocks.add(match.first);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ExpansionTile(
          title: Text('Treino: ${_wr!.name}'),
          subtitle:
              Text('Blocos: ${blocks.length}  |  Esquema: ${_wr!.repetitionSchema}'),
          initiallyExpanded: true,
          children: [for (final b in blocks) _workoutBlockTile(b)],
        ),
      ),
    );
  }

  Widget _workoutBlockTile(WorkoutBlock b) {
    final days = <WorkoutDay>[];
    for (final ds in b.daySlugs) {
      final match =
          _wDayBox.values.where((d) => d.id == ds || toSlug(d.name) == ds).toList();
      if (match.isNotEmpty) days.add(match.first);
    }

    return ExpansionTile(
      title: Text('Bloco: ${b.name}'),
      subtitle: Text('Dias: ${days.length}'),
      children: [for (final d in days) _workoutDayTile(d)],
    );
  }

  Widget _workoutDayTile(WorkoutDay d) {
    final sessions = d.sessions.toList();
    return ExpansionTile(
      title: Text('Dia: ${d.name}'),
      subtitle: Text('Sessões: ${sessions.length}'),
      children: [for (final s in sessions) _workoutSessionTile(s)],
    );
  }

  Widget _workoutSessionTile(WorkoutSession s) {
    final exercises = s.exercises.toList();
    return ExpansionTile(
      title: Text('Sessão: ${s.name}'),
      subtitle: Text('Exercícios: ${exercises.length}'),
      children: [
        for (final e in exercises)
          ListTile(
            dense: true,
            title: Text(e.name),
            subtitle: Text(
              'Primários: ${e.primaryMuscles.join(", ")}; '
              'Secundários: ${e.secondaryMuscles.join(", ")}',
            ),
          ),
      ],
    );
  }

  // ---------- DIET ----------
  Widget _buildDietSection() {
    if (_dr == null) {
      return const Card(
        child: ListTile(title: Text('Nenhuma rotina de dieta encontrada.')),
      );
    }

    final blockSlugs = _ds?.blockSequence ?? const <String>[];
    final blocks = <DietBlock>[];
    for (final slug in blockSlugs) {
      final match = _dBlockBox.values.where((b) => b.slug == slug).toList();
      if (match.isNotEmpty) blocks.add(match.first);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ExpansionTile(
          title: Text('Dieta: ${_dr!.name}'),
          subtitle:
              Text('Blocos: ${blocks.length}  |  Esquema: ${_dr!.repetitionSchema}'),
          initiallyExpanded: true,
          children: [for (final b in blocks) _dietBlockTile(b)],
        ),
      ),
    );
  }

  Widget _dietBlockTile(DietBlock b) {
    final days = <DietDay>[];
    for (final ds in b.daySlugs) {
      final match = _dDayBox.values.where((d) => d.id == ds).toList();
      if (match.isNotEmpty) days.add(match.first);
    }

    return ExpansionTile(
      title: Text('Bloco: ${b.name}'),
      subtitle: Text('Dias: ${days.length}'),
      children: [
        for (final d in days)
          ListTile(
            title: Text('Dia: ${d.name}'),
            subtitle: Text(d.description),
          ),
      ],
    );
  }
}

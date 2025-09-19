// lib/features/3_planner/presentation/pages/planner_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive/hive.dart';

import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/features/3_planner/presentation/pages/new_plan_flow_screen.dart';

import 'package:fitapp/core/models/workout_routine.dart';
import 'package:fitapp/core/models/workout_routine_schedule.dart';
import 'package:fitapp/core/models/workout_block.dart';
import 'package:fitapp/core/models/workout_day.dart';
import 'package:fitapp/core/models/diet_routine.dart';
import 'package:fitapp/core/models/diet_block.dart';

import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final ValueNotifier<List<String>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  WorkoutRoutine? _workoutRoutine;
  WorkoutRoutineSchedule? _workoutSchedule;
  DietRoutine? _dietRoutine;

  // caches (boxes tipados)
  late final Box<WorkoutBlock> _wBlockBox;
  late final Box<WorkoutDay> _wDayBox;
  late final Box<DietBlock> _dBlockBox;
  late final Box<WorkoutRoutineSchedule> _wScheduleBox;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier<List<String>>(<String>[]);
    // carrega depois do primeiro frame (context OK)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoutines();
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  void _loadRoutines() {
    final hive = context.read<HiveService>();

    // abre boxes
    _wBlockBox = hive.getBox<WorkoutBlock>('workout_blocks');
    _wDayBox = hive.getBox<WorkoutDay>('workout_days');
    _dBlockBox = hive.getBox<DietBlock>('diet_blocks');
    _wScheduleBox = hive.getBox<WorkoutRoutineSchedule>('routine_schedules');

    final wRoutines = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    final dRoutines = hive.getBox<DietRoutine>('diet_routines').values.toList();

    final selectedWorkoutRoutine = wRoutines.isEmpty ? null : wRoutines.first;
    final selectedDietRoutine = dRoutines.isEmpty ? null : dRoutines.first;

    WorkoutRoutineSchedule? resolvedSchedule;
    if (selectedWorkoutRoutine != null) {
      final rSlug = toSlug(selectedWorkoutRoutine.name);
      final matches = _wScheduleBox.values.where((s) => s.routineSlug == rSlug).toList();
      resolvedSchedule = matches.isEmpty ? null : matches.first;
    }

    setState(() {
      _workoutRoutine = selectedWorkoutRoutine;
      _dietRoutine = selectedDietRoutine;
      _workoutSchedule = resolvedSchedule;
    });
  }

  List<String> _resolveWorkoutEventsForDay(DateTime day) {
    final wr = _workoutRoutine;
    final ws = _workoutSchedule;
    if (wr == null || ws == null) return const <String>[];

    // Se seu model não tiver startDate, substitua por uma data base fixa.
    final routineStart = wr.startDate ?? DateTime.now();
    final base = DateTime(routineStart.year, routineStart.month, routineStart.day);
    final diff = day.difference(base).inDays;
    if (diff < 0) return const <String>[];

    // monta sequência de slugs de dias a partir dos blocos do schedule
    final daySlugsSequence = <String>[];
    for (final bslug in ws.blockSequence) {
      final blockMatches = _wBlockBox.values.where((b) => b.slug == bslug).toList();
      if (blockMatches.isEmpty) continue;
      final block = blockMatches.first;
      daySlugsSequence.addAll(block.daySlugs);
    }
    if (daySlugsSequence.isEmpty) return const <String>[];

    final idx = diff % daySlugsSequence.length;
    final daySlug = daySlugsSequence[idx];

    // resolve WorkoutDay pelo slug do nome
    final dayMatch = _wDayBox.values.firstWhere(
      (d) => toSlug(d.name) == daySlug,
      orElse: () => _wDayBox.values.isEmpty ? null as WorkoutDay : _wDayBox.values.first,
    );
    if (dayMatch == null) return const <String>[];

    // Se seu model tiver isRest e você quiser ocultar:
    // if (dayMatch.isRest == true) return const <String>[];

    return <String>['Treino: ${dayMatch.name}'];
  }

  List<String> _resolveDietEventsForDay(DateTime day) {
    final dr = _dietRoutine;
    if (dr == null) return const <String>[];

    // Se seu model não tiver startDate, substitua por uma data base fixa.
    final routineStart = dr.startDate ?? DateTime.now();
    final base = DateTime(routineStart.year, routineStart.month, routineStart.day);
    final diff = day.difference(base).inDays;
    if (diff < 0) return const <String>[];

    // IMPORTANTE: assume que DietRoutine possui `blockSlugs: List<String>`
    // Se ainda não tiver, ajuste aqui para sua estrutura atual.
    final dBlockSlugs = dr.blockSlugs ?? const <String>[];
    if (dBlockSlugs.isEmpty) return const <String>[];

    final dietDaySlugs = <String>[];
    for (final bslug in dBlockSlugs) {
      final matches = _dBlockBox.values.where((b) => b.slug == bslug).toList();
      if (matches.isEmpty) continue;
      dietDaySlugs.addAll(matches.first.daySlugs);
    }
    if (dietDaySlugs.isEmpty) return const <String>[];

    final idx = diff % dietDaySlugs.length;
    final slug = dietDaySlugs[idx];

    // Aqui mostramos o slug do dia. Se quiser resolver para DietDay pelo box 'diet_days', faça algo similar ao WorkoutDay.
    return <String>['Dieta: $slug'];
  }

  List<String> _getEventsForDay(DateTime day) {
    final out = <String>[];
    out.addAll(_resolveWorkoutEventsForDay(day));
    out.addAll(_resolveDietEventsForDay(day));
    return out;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planejador')),
      body: Column(
        children: [
          TableCalendar<String>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2026, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _getEventsForDay,
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return const Center(child: Text('Nenhuma atividade planejada.'));
                }
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (_, i) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        value[i].startsWith('Treino') ? Icons.fitness_center : Icons.restaurant,
                      ),
                      title: Text(value[i]),
                      onTap: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewPlanFlowScreen()),
        ),
        label: const Text('Gerar Plano com IA'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/features/3_planner/presentation/pages/new_plan_flow_screen.dart';
import 'package:hive/hive.dart';

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
  Map<String, dynamic>? _routineScheduleRaw; // {id, routineId, slots:[{kind, dayId}]}
  DietRoutine? _dietRoutine;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadRoutines();
  }

  void _loadRoutines() {
    final hive = context.read<HiveService>();
    final wr = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    final dr = hive.getBox<DietRoutine>('diet_routines').values.toList();
    setState(() {
      _workoutRoutine = wr.isEmpty ? null : wr.first;
      _dietRoutine = dr.isEmpty ? null : dr.first;
      // schedule raw salvo pelo repo em routine_schedules (Map)
      final schedBox = Hive.box('routine_schedules');
      if (_workoutRoutine != null) {
        _routineScheduleRaw = schedBox.get(_workoutRoutine!.id) as Map<String, dynamic>?;
      } else {
        _routineScheduleRaw = null;
      }
    });
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
  }

  List<String> _getEventsForDay(DateTime day) {
    final List<String> events = [];

    // Workout via schedule
    if (_workoutRoutine != null && _routineScheduleRaw != null) {
      final r = _workoutRoutine!;
      final slots = List<Map>.from(_routineScheduleRaw!['slots'] as List);
      final diff = day.difference(r.startDate).inDays;
      if (diff >= 0 && slots.isNotEmpty) {
        final idx = diff % slots.length;
        final slot = slots[idx];
        if (slot['kind'] == 'rest') {
          // nada
        } else if (slot['kind'] == 'day') {
          final dayId = slot['dayId'] as String?;
          if (dayId != null) {
            final d = r.days.firstWhere((x) => x.id == dayId, orElse: () => r.days.first);
            events.add('Treino: ${d.name}');
          }
        }
      }
    }

    // Diet
    if (_dietRoutine != null) {
      final r = _dietRoutine!;
      final diff = day.difference(r.startDate).inDays;
      if (diff >= 0 && r.days.isNotEmpty) {
        final idx = diff % r.days.length;
        final dd = r.days[idx];
        events.add('Dieta: ${dd.name}');
      }
    }

    return events;
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
      body: Column(children: [
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
              if (value.isEmpty) return const Center(child: Text('Nenhuma atividade planejada.'));
              return ListView.builder(
                itemCount: value.length,
                itemBuilder: (_, i) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Icon(value[i].startsWith('Treino') ? Icons.fitness_center : Icons.restaurant),
                    title: Text(value[i]),
                    onTap: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPlanFlowScreen())),
        label: const Text('Gerar Plano com IA'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}

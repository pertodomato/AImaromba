import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/features/3_planner/presentation/pages/new_plan_flow_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadRoutines();
  }

  void _loadRoutines() {
    final hive = context.read<HiveService>();
    final rts = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    setState(() => _workoutRoutine = rts.isEmpty ? null : rts.first);
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
  }

  List<String> _getEventsForDay(DateTime day) {
    final List<String> events = [];
    if (_workoutRoutine != null) {
      final r = _workoutRoutine!;
      final diff = day.difference(r.startDate).inDays;
      if (diff >= 0 && r.days.isNotEmpty) {
        final idx = diff % r.days.length;
        final wd = r.days[idx];
        if (wd.name.toLowerCase() != 'descanso') {
          events.add('Treino: ${wd.name}');
        }
      }
    }
    // (Extensão futura) diet routine aqui
    return events;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  void dispose() { _selectedEvents.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planejador')),
      body: Column(
        children: [
          TableCalendar<String>(
            firstDay: DateTime.utc(2024,1,1),
            lastDay: DateTime.utc(2026,12,31),
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
                      leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPlanFlowScreen())),
        label: const Text('Gerar Plano com IA'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}

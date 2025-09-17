import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/features/3_planner/presentation/pages/new_plan_flow_screen.dart';
// Importe seus modelos de rotina. Ex:
// import 'package:seu_app/core/models/workout_routine.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  // Gerencia o estado do calendário
  late final ValueNotifier<List<String>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Armazena as rotinas carregadas do banco de dados
  // TODO: Substitua 'dynamic' pelos seus modelos de dados reais (ex: WorkoutRoutine)
  dynamic _workoutRoutine;
  // dynamic _dietRoutine;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    
    // Carrega as rotinas do banco de dados ao iniciar a tela
    _loadRoutines();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }
  
  /// Carrega as rotinas ativas do HiveService.
  void _loadRoutines() {
    // Exemplo de como carregar uma rotina. Adapte para sua lógica.
    // final routines = context.read<HiveService>().getBox('workout_routines').values;
    // if (routines.isNotEmpty) {
    //   setState(() {
    //     _workoutRoutine = routines.first; // Pega a primeira rotina como ativa
    //   });
    // }
  }

  /// Retorna uma lista de eventos para um determinado dia.
  /// Esta é a principal função de integração de dados.
  List<String> _getEventsForDay(DateTime day) {
    // Esta é uma lógica de exemplo. Você precisará adaptá-la
    // com base em como suas rotinas (WorkoutRoutine, DietRoutine) são estruturadas.
    // Por exemplo, se a rotina repete a cada 7 dias (ABC Descanso ABC Descanso):
    if (_workoutRoutine != null) {
      // Supondo que sua rotina tenha uma data de início e uma sequência de dias.
      // final routineStartDate = _workoutRoutine.startDate;
      // final daysSinceStart = day.difference(routineStartDate).inDays;
      // final routineCycleLength = _workoutRoutine.day_sequence.length;

      // if (daysSinceStart >= 0) {
      //   final dayIndexInCycle = daysSinceStart % routineCycleLength;
      //   final workoutDayName = _workoutRoutine.day_sequence[dayIndexInCycle];
      //   if (workoutDayName != "descanso") {
      //     return ['Treino: $workoutDayName'];
      //   }
      // }
    }
    // Retorna uma lista vazia se não houver eventos para o dia.
    return [];
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejador'),
      ),
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
            calendarStyle: const CalendarStyle(
              // Estiliza os marcadores de evento
              markerDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 8.0),
          const Divider(),
          Expanded(
            // Usa um ValueListenableBuilder para reconstruir apenas a lista de eventos
            // quando _selectedEvents mudar, o que é mais performático.
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma atividade planejada para este dia.'),
                  );
                }
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
                        title: Text(value[index]),
                        onTap: () {
                          // TODO: Navegar para os detalhes do treino/refeição
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegação corrigida para a tela de criação do plano
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewPlanFlowScreen()),
          );
        },
        label: const Text('Gerar Plano com IA'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
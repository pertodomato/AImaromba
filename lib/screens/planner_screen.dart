import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/app_drawer.dart'; // + import

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime focused = DateTime.now();
  DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final profile = Hive.box('profile');
    String? rid = profile.get('activeRoutine');
    if (rid == null) {
      // cria rotina vazia
      rid = 'routine_default';
      Hive.box('routine').put(rid, {'id': rid, 'name': 'Rotina', 'calendar': {}});
      profile.put('activeRoutine', rid);
    }
    final routine = Hive.box('routine').get(rid);

    return Scaffold(
      appBar: AppBar(title: const Text('Planejador de Rotina')),
      drawer: const AppNavDrawer(),
      body: Column(children: [
        TableCalendar(
          firstDay: DateTime.utc(2020,1,1),
          lastDay: DateTime.utc(2035,12,31),
          focusedDay: focused,
          selectedDayPredicate: (d)=> selected!=null && isSameDay(d, selected),
          onDaySelected: (d, f){ setState((){ selected=d; focused=f; }); _assign(d, routine); },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (_, date, __){
              final key = date.toIso8601String().substring(0,10);
              final v = routine['calendar'][key];
              if (v==null) return null; return Icon(v=='descanso'? Icons.hotel : Icons.fitness_center, size: 12);
            }
          ),
        ),
        const SizedBox(height: 8),
        if (selected!=null) _infoForDay(selected!, routine),
      ]),
    );
  }

  Widget _infoForDay(DateTime d, Map routine){
    final key = d.toIso8601String().substring(0,10);
    final val = routine['calendar'][key];
    return ListTile(
      title: Text('Dia ${key}'),
      subtitle: Text(val==null? 'Sem treino' : (val=='descanso'?'Descanso':'Bloco $val')),
    );
  }

  Future<void> _assign(DateTime day, Map routine) async {
    final blocks = Hive.box('blocks');
    final chosen = await showDialog<String>(
      context: context,
      builder: (_){
        return SimpleDialog(title: Text('Agendar ${day.toIso8601String().substring(0,10)}'), children: [
          SimpleDialogOption(onPressed: ()=> Navigator.pop(context, 'descanso'), child: const Text('Descanso')),
          ...blocks.values.map<Widget>((b)=> SimpleDialogOption(onPressed: ()=> Navigator.pop(context, b['id']), child: Text(b['name']))).toList()
        ]);
      }
    );
    if (chosen==null) return;
    final key = day.toIso8601String().substring(0,10);
    routine['calendar'][key] = chosen;
    Hive.box('routine').put(routine['id'], routine);
    setState((){});
  }
}

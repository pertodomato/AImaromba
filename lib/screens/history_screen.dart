import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import '../widgets/app_drawer.dart'; // + import

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<DateTime> days; // últimos 7 dias (hoje inclusive)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  Map<DateTime, double> _burnedPerDay() {
    final sessions = Hive.box('sessions').values.cast<Map>();
    final map = <DateTime, double>{ for (final d in days) d: 0.0 };
    for (final s in sessions) {
      final dateStr = (s['date'] as String?);
      if (dateStr == null) continue;
      final dt = DateTime.tryParse('${dateStr}T12:00:00') ??
          DateTime.tryParse(dateStr) ??
          DateTime.now();
      final key = DateTime(dt.year, dt.month, dt.day);
      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + ((s['calories'] ?? 0) as num).toDouble();
      }
    }
    return map;
  }

  Map<DateTime, double> _consumedPerDay() {
    final logs = Hive.box('foodlogs').values.cast<Map>();
    final map = <DateTime, double>{ for (final d in days) d: 0.0 };
    for (final l in logs) {
      final dateStr = (l['date'] as String?);
      if (dateStr == null) continue;
      final dt = DateTime.tryParse('${dateStr}T12:00:00') ??
          DateTime.tryParse(dateStr) ??
          DateTime.now();
      final key = DateTime(dt.year, dt.month, dt.day);
      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + ((l['kcal'] ?? 0) as num).toDouble();
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final burned = _burnedPerDay();
    final consumed = _consumedPerDay();
    final target = (Hive.box('profile').get('calorieTarget', defaultValue: 2000) as num).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico & Gráficos')),
      drawer: const AppNavDrawer(), // <-- ADICIONE
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Kcal gastas por dia (últimos 7 dias)',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          final d = days[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10)),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      spots: [
                        for (int i = 0; i < days.length; i++)
                          FlSpot(i.toDouble(), (burned[days[i]] ?? 0).toDouble()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Kcal consumidas vs meta (últimos 7 dias)',
            child: SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  barGroups: [
                    for (int i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(toY: (consumed[days[i]] ?? 0).toDouble()),
                          BarChartRodData(toY: target),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          final d = days[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10)),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dica: registre treinos (gasta) e refeições (consome) por alguns dias para ver os gráficos ganharem vida.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }
}

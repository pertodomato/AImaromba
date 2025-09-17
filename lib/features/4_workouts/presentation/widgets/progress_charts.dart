import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_set_entry.dart';
import 'package:seu_app/core/services/hive_service.dart';

/// Heurística simples: cardio se métricas contêm Distância ou Tempo.
bool _isCardio(Exercise e) =>
    e.relevantMetrics.any((m) => m == 'Distância' || m == 'Tempo');

/// Volume força: soma Peso*Reps por set.
double _strengthSetVolume(WorkoutSetEntry e) {
  final w = e.metrics['Peso'] ?? 0;
  final r = e.metrics['Repetições'] ?? 0;
  return w * r;
}

/// Cardio: prioriza Distância, senão Tempo (min).
double _cardioSetLoad(WorkoutSetEntry e) {
  final d = e.metrics['Distância'];
  if (d != null) return d;
  final t = e.metrics['Tempo'];
  return (t ?? 0);
}

class ProgressCharts extends StatelessWidget {
  const ProgressCharts({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = context.watch<HiveService>();
    final setBox = hive.getBox<WorkoutSetEntry>('workout_set_entries');
    final exBox = hive.getBox<Exercise>('exercises');
    final sets = setBox.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final allExercises = exBox.values.toList();

    // Por exercício: usa melhor 1RM estimado por dia (aproximação: Epley inline).
    final perExerciseSeries = <String, List<FlSpot>>{};
    for (final ex in allExercises) {
      final exSets = sets.where((s) => s.exerciseId == ex.id).toList();
      if (exSets.isEmpty) continue;

      final groupedByDay = groupBy<WorkoutSetEntry, DateTime>(
        exSets,
        (s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day),
      );

      final entries = groupedByDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      final spots = <FlSpot>[];
      for (var i = 0; i < entries.length; i++) {
        final daySets = entries[i].value;
        double best = 0;
        for (final s in daySets) {
          final w = s.metrics['Peso'] ?? 0;
          final r = s.metrics['Repetições'] ?? 0;
          if (w > 0 && r > 0) {
            final est = w * (1 + r / 30); // Epley
            if (est > best) best = est;
          }
        }
        if (best > 0) spots.add(FlSpot(i.toDouble(), best));
      }
      if (spots.length >= 2) {
        perExerciseSeries[ex.name] = spots;
      }
    }

    // Por categoria: força(vol/kg*reps) semanal, cardio(distância km ou tempo min) semanal.
    final weeks = groupBy<WorkoutSetEntry, String>(sets, (s) {
      final monday = s.timestamp.subtract(Duration(days: (s.timestamp.weekday - 1)));
      final k = DateTime(monday.year, monday.month, monday.day);
      return '${k.year}-${k.month}-${k.day}';
    }).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final strengthSpots = <FlSpot>[];
    final cardioSpots = <FlSpot>[];

    for (var i = 0; i < weeks.length; i++) {
      final wsets = weeks[i].value;
      double strength = 0;
      double cardio = 0;

      for (final s in wsets) {
        final ex = allExercises.firstWhereOrNull((e) => e.id == s.exerciseId);
        if (ex == null) continue;
        if (_isCardio(ex)) {
          cardio += _cardioSetLoad(s);
        } else {
          strength += _strengthSetVolume(s);
        }
      }
      strengthSpots.add(FlSpot(i.toDouble(), strength));
      cardioSpots.add(FlSpot(i.toDouble(), cardio));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Progressão por Exercício (1RM estimado)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (perExerciseSeries.isEmpty)
          const Card(child: SizedBox(height: 180, child: Center(child: Text('Sem dados suficientes'))))
        else
          ...perExerciseSeries.entries.take(3).map((e) => _lineCard(title: e.key, spots: e.value)),
        const SizedBox(height: 16),
        Text('Carga Semanal: Força vs Cardio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _dualLineCard(strengthSpots, cardioSpots, 'Força (ΣPeso×Reps)', 'Cardio (Dist/Tempo)'),
      ],
    );
  }

  Widget _lineCard({required String title, required List<FlSpot> spots}) {
    return Card(
      child: SizedBox(
        height: 180,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [LineChartBarData(spots: spots, isCurved: true, barWidth: 3)],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dualLineCard(List<FlSpot> s1, List<FlSpot> s2, String l1, String l2) {
    return Card(
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l1), Text(l2)]),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(spots: s1, isCurved: true, barWidth: 3),
                    LineChartBarData(spots: s2, isCurved: true, barWidth: 3),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

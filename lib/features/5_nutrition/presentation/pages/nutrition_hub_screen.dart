import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/core/services/hive_service.dart';

class NutritionHubScreen extends StatelessWidget {
  const NutritionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = context.watch<HiveService>();
    final mealEntries = hive.getBox<MealEntry>('meal_entries').values.toList();
    final weightEntries = hive.getBox<WeightEntry>('weight_entries').values.toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final profile = hive.getUserProfile();

    // Hoje
    final now = DateTime.now();
    final todayMeals = mealEntries.where((e) => _isSameDay(e.dateTime, now)).toList();
    final totalKcal = todayMeals.fold(0.0, (s, e) => s + e.calories);
    final totalProt = todayMeals.fold(0.0, (s, e) => s + e.protein);
    final totalCarb = todayMeals.fold(0.0, (s, e) => s + e.carbs);
    final totalFat = todayMeals.fold(0.0, (s, e) => s + e.fat);

    // MTD
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final daysPassed = now.day;
    final mtdMeals = mealEntries.where((e) => e.dateTime.isAfter(firstOfMonth.subtract(const Duration(seconds: 1))) && e.dateTime.isBefore(now.add(const Duration(days: 1)))).toList();
    final mtdKcal = mtdMeals.fold(0.0, (s, e) => s + e.calories);
    final mtdProt = mtdMeals.fold(0.0, (s, e) => s + e.protein);

    final dailyKcalGoal = (profile.dailyKcalGoal ?? 2000).toDouble();
    final dailyProtGoal = (profile.dailyProteinGoal ?? 120).toDouble();
    final targetKcalMTD = dailyKcalGoal * daysPassed;
    final targetProtMTD = dailyProtGoal * daysPassed;

    final kcalOnTrack = mtdKcal <= targetKcalMTD * 1.05 && mtdKcal >= targetKcalMTD * 0.95;
    final protOnTrack = mtdProt >= targetProtMTD * 0.9;

    // Pizza de macros
    final sumMacros = (totalProt + totalCarb + totalFat);
    final sections = sumMacros == 0
        ? <PieChartSectionData>[]
        : [
            PieChartSectionData(value: totalCarb, title: '${(totalCarb / sumMacros * 100).toStringAsFixed(0)}% Carb'),
            PieChartSectionData(value: totalProt, title: '${(totalProt / sumMacros * 100).toStringAsFixed(0)}% Prot'),
            PieChartSectionData(value: totalFat, title: '${(totalFat / sumMacros * 100).toStringAsFixed(0)}% Gord'),
          ];

    // Peso
    final spots = weightEntries.isEmpty
        ? <FlSpot>[]
        : List<FlSpot>.generate(weightEntries.length, (i) => FlSpot(i.toDouble(), weightEntries[i].weightKg));

    final dateFmt = DateFormat('dd/MM HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Central de Nutrição')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Macros de Hoje (kcal: ${totalKcal.toStringAsFixed(0)})', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: sections.isEmpty ? const Center(child: Text('Sem refeições hoje')) : PieChart(PieChartData(sections: sections)),
          ),
          const SizedBox(height: 24),
          Text('Progresso do Peso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: spots.isEmpty
                ? const Center(child: Text('Sem registros de peso'))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, barWidth: 4)],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text('MTD vs Meta', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(kcalOnTrack ? Icons.check_circle : Icons.error, color: kcalOnTrack ? Colors.green : Colors.amber),
              title: const Text('Calorias no mês'),
              subtitle: Text('Consumido: ${mtdKcal.toStringAsFixed(0)} / Alvo: ${targetKcalMTD.toStringAsFixed(0)}'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(protOnTrack ? Icons.check_circle : Icons.error, color: protOnTrack ? Colors.green : Colors.amber),
              title: const Text('Proteína no mês'),
              subtitle: Text('Consumido: ${mtdProt.toStringAsFixed(0)}g / Alvo: ${targetProtMTD.toStringAsFixed(0)}g'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Refeições Recentes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (mealEntries.isEmpty)
            const Card(child: ListTile(title: Text('Nenhuma refeição registrada.')))
          else
            ...mealEntries.reversed.take(10).map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.restaurant),
                    title: Text('${e.label} — ${e.meal.name}'),
                    subtitle: Text(dateFmt.format(e.dateTime)),
                    trailing: Text('${e.calories.toStringAsFixed(0)} kcal'),
                  ),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use o + na Home para registrar.')));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

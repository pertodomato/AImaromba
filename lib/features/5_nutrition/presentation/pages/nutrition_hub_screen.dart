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
    final weightEntries = hive.getBox<WeightEntry>('weight_entries').values.toList()..sort((a,b)=>a.dateTime.compareTo(b.dateTime));

    // Agregação diária de macros
    final now = DateTime.now();
    final todayMeals = mealEntries.where((e) => e.dateTime.year==now.year && e.dateTime.month==now.month && e.dateTime.day==now.day).toList();
    final totalKcal = todayMeals.fold(0.0, (s,e)=>s+e.calories);
    final totalProt = todayMeals.fold(0.0, (s,e)=>s+e.protein);
    final totalCarb = todayMeals.fold(0.0, (s,e)=>s+e.carbs);
    final totalFat  = todayMeals.fold(0.0, (s,e)=>s+e.fat);

    // Pizza de macros (% relativo)
    final sumMacros = (totalProt + totalCarb + totalFat);
    final sections = sumMacros == 0 ? <PieChartSectionData>[] : [
      PieChartSectionData(value: totalCarb, title: '${(totalCarb/sumMacros*100).toStringAsFixed(0)}% Carb'),
      PieChartSectionData(value: totalProt, title: '${(totalProt/sumMacros*100).toStringAsFixed(0)}% Prot'),
      PieChartSectionData(value: totalFat,  title: '${(totalFat /sumMacros*100).toStringAsFixed(0)}% Gord'),
    ];

    // Gráfico de peso
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
            child: sections.isEmpty
                ? const Center(child: Text('Sem refeições hoje'))
                : PieChart(PieChartData(sections: sections)),
          ),
          const SizedBox(height: 24),
          Text('Progresso do Peso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: spots.isEmpty
                ? const Center(child: Text('Sem registros de peso'))
                : LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [LineChartBarData(spots: spots, isCurved: true, barWidth: 4)],
                  )),
          ),
          const SizedBox(height: 24),
          Text('Refeições Recentes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (mealEntries.isEmpty)
            const Card(child: ListTile(title: Text('Nenhuma refeição registrada.'))),
          if (mealEntries.isNotEmpty)
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
          // Sugestão: reutilize o FAB da Home (abrir o mesmo modal) via Navigator.pop/Routes.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use o + na Home para registrar.')));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

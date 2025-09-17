import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class NutritionHubScreen extends StatelessWidget {
  const NutritionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Nutrição'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Gráfico de Pizza de Macros
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    color: Colors.blue,
                    value: 40,
                    title: '40% Carb',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: Colors.red,
                    value: 30,
                    title: '30% Prot',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: Colors.yellow,
                    value: 30,
                    title: '30% Gord',
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Progresso do Peso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          // Gráfico de Linha de Progresso do Peso
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 80),
                      FlSpot(1, 81),
                      FlSpot(2, 80.5),
                      FlSpot(3, 79),
                      FlSpot(4, 78.5),
                    ],
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Lista de Refeições
          Text('Refeições Recentes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.breakfast_dining),
              title: const Text('Café da Manhã'),
              subtitle: const Text('Ovos, aveia e banana'),
              trailing: const Text('450 kcal'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lunch_dining),
              title: const Text('Almoço'),
              subtitle: const Text('Frango, arroz e salada'),
              trailing: const Text('600 kcal'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Lógica para adicionar nova refeição
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
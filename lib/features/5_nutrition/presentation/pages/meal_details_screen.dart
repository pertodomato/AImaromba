// lib/features/5_nutrition/presentation/pages/meal_details_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fitapp/core/models/meal_entry.dart';
import 'package:fitapp/core/models/meal_estimate.dart' as est;

class MealDetailsScreen extends StatefulWidget {
  final MealEntry mealEntry;
  final String? imagePath;
  final String? aiResponseJson;

  const MealDetailsScreen({
    super.key,
    required this.mealEntry,
    this.imagePath,
    this.aiResponseJson,
  });

  @override
  State<MealDetailsScreen> createState() => _MealDetailsScreenState();
}

class _MealDetailsScreenState extends State<MealDetailsScreen> {
  int? _touchedIndex;
  List<est.MealComponent> _components = [];

  @override
  void initState() {
    super.initState();
    _parseComponents();
  }

  void _parseComponents() {
    if (widget.aiResponseJson == null) return;
    try {
      final json = jsonDecode(widget.aiResponseJson!);
      final compList = (json['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      setState(() {
        _components = compList.map((e) => est.MealComponent.fromJson(e)).toList();
      });
    } catch (e) {
      print("Erro ao parsear componentes da refeição: $e");
      // Silenciosamente ignora o erro, a lista de componentes apenas não aparecerá
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.mealEntry.meal;
    final grams = widget.mealEntry.grams;
    final totalCalories = widget.mealEntry.calories;
    final totalProteinG = widget.mealEntry.protein;
    final totalCarbsG = widget.mealEntry.carbs;
    final totalFatG = widget.mealEntry.fat;

    final proteinCalories = totalProteinG * 4;
    final carbsCalories = totalCarbsG * 4;
    final fatCalories = totalFatG * 9;

    return Scaffold(
      appBar: AppBar(
        title: Text(meal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Confirmar',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (widget.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: kIsWeb
                  ? Image.network(widget.imagePath!, height: 250, fit: BoxFit.cover)
                  : Image.file(File(widget.imagePath!), height: 250, fit: BoxFit.cover),
            ),
          const SizedBox(height: 24),
          Text(
            'Resumo Nutricional (${grams.toStringAsFixed(0)} g)',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildPieChart(totalCalories, proteinCalories, carbsCalories, fatCalories),
          const SizedBox(height: 16),
          _buildSummaryCard(totalCalories, totalProteinG, totalCarbsG, totalFatG),
          if (_components.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Componentes Identificados', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildComponentsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPieChart(double totalCalories, double proteinCalories, double carbsCalories, double fatCalories) {
    // Evita divisão por zero se não houver calorias
    final safeTotalCalories = totalCalories > 0 ? totalCalories : 1.0;

    return Card(
      child: AspectRatio(
        aspectRatio: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                _buildPieSection(
                  value: proteinCalories,
                  title: '${(proteinCalories / safeTotalCalories * 100).toStringAsFixed(0)}%',
                  color: Colors.redAccent,
                  isTouched: _touchedIndex == 0,
                ),
                _buildPieSection(
                  value: carbsCalories,
                  title: '${(carbsCalories / safeTotalCalories * 100).toStringAsFixed(0)}%',
                  color: Colors.blueAccent,
                  isTouched: _touchedIndex == 1,
                ),
                _buildPieSection(
                  value: fatCalories,
                  title: '${(fatCalories / safeTotalCalories * 100).toStringAsFixed(0)}%',
                  color: Colors.amber,
                  isTouched: _touchedIndex == 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PieChartSectionData _buildPieSection({
    required double value,
    required String title,
    required Color color,
    required bool isTouched,
  }) {
    final fontSize = isTouched ? 18.0 : 14.0;
    final radius = isTouched ? 60.0 : 50.0;
    return PieChartSectionData(
      color: color,
      value: value,
      title: title,
      radius: radius,
      titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }
  
  Widget _buildSummaryCard(double calories, double protein, double carbs, double fat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMacroRow('Calorias', calories, 'kcal', Icons.local_fire_department),
            const Divider(),
            _buildMacroRow('Proteínas', protein, 'g', Icons.fitness_center, Colors.redAccent),
            const Divider(),
            _buildMacroRow('Carboidratos', carbs, 'g', Icons.rice_bowl, Colors.blueAccent),
            const Divider(),
            _buildMacroRow('Gorduras', fat, 'g', Icons.local_dining, Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(String label, double value, String unit, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsCard() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _components.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final comp = _components[index];
          return ListTile(
            title: Text(comp.name),
            subtitle: Text('${comp.estimatedWeightG.toStringAsFixed(0)} g'),
            trailing: Text('${comp.caloriesTotal.toStringAsFixed(0)} kcal'),
          );
        },
      ),
    );
  }
}
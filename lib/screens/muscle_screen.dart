// lib/screens/muscle_screen.dart
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:muscle_selector/src/parser.dart';
import '../data/repositories/workout_repository.dart';
import '../presentation/providers/muscle_analysis_providers.dart';
import '../widgets/app_drawer.dart';

enum MuscleMode { treino, comparativo }

class MuscleScreen extends ConsumerStatefulWidget {
  const MuscleScreen({super.key});
  @override
  ConsumerState<MuscleScreen> createState() => _MuscleScreenState();
}

class _MuscleScreenState extends ConsumerState<MuscleScreen> {
  final GlobalKey<MusclePickerMapState> _mapKey = GlobalKey();
  MuscleMode _mode = MuscleMode.treino;
  String? selectedMuscleId;

  // Dicionário de cores para os buckets
  static const Map<String, Color> _bucketColors = {
    'green': Colors.green,
    'yellow': Colors.yellow,
    'red': Colors.red,
    'purple': Color(0xFF4A148C),
  };

  // ---------- Interação com o Mapa ----------
  void _resetSelection() {
    _mapKey.currentState?.clearSelect();
    setState(() => selectedMuscleId = null);
  }

  void _onMapChanged(Set<Muscle> muscles) {
    setState(() {
      selectedMuscleId = muscles.isEmpty ? null : muscles.last.id;
    });
  }

  String _getGroupForMuscleId(String muscleId) {
    for (var entry in Parser.muscleGroups.entries) {
      if (entry.value.contains(muscleId)) return entry.key;
    }
    return '';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mapWidth = min(420.0, size.width - 32);
    final mapHeight = mapWidth * 1.15;

    final muscleTitle = selectedMuscleId != null
        ? selectedMuscleId!.replaceAll('_', ' ').split(RegExp(r'(?=\\d)')).join(' ').toUpperCase()
        : 'Análise Muscular';

    // Assiste ao provider para obter os dados de análise
    final analysisAsync = ref.watch(muscleAnalysisProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(muscleTitle),
        actions: [
          if (selectedMuscleId != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Limpar Seleção',
              onPressed: _resetSelection,
            ),
        ],
      ),
      drawer: const AppNavDrawer(),
      body: analysisAsync.when(
        data: (analysisData) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildControls(),
              const SizedBox(height: 12),
              _buildMapWithHeat(mapWidth, mapHeight, analysisData),
              const SizedBox(height: 12),
              _legend(
                title: _mode == MuscleMode.treino ? 'Recência de Treino' : 'Nível de Força (Percentil)',
                items: const [
                  ('Recente (0-2 dias)', Colors.red),
                  ('Médio (3-5 dias)', Colors.yellow),
                  ('Descansado (6+ dias)', Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: selectedMuscleId == null
                    ? _buildOverallHistoryView(analysisData.workoutHistory)
                    : _buildIndividualMuscleHistoryView(selectedMuscleId!, analysisData.workoutHistory),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro ao carregar dados: $error')),
      ),
    );
  }

  Widget _buildControls() {
    return SegmentedButton<MuscleMode>(
      segments: const [
        ButtonSegment(value: MuscleMode.treino, icon: Icon(Icons.whatshot), label: Text('Recência')),
        ButtonSegment(value: MuscleMode.comparativo, icon: Icon(Icons.bar_chart), label: Text('Percentil')),
      ],
      selected: <MuscleMode>{_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  Widget _buildMapWithHeat(double mapWidth, double mapHeight, MuscleAnalysisData analysisData) {
    final buckets = (_mode == MuscleMode.treino)
        ? analysisData.recencyBuckets
        : analysisData.percentileBuckets;

    return Center(
      child: SizedBox(
        width: mapWidth,
        height: mapHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ...buckets.entries.map((entry) => _HeatLayer(
                  groups: entry.value,
                  color: _bucketColors[entry.key] ?? Colors.transparent,
                  width: mapWidth,
                  height: mapHeight,
                )),
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _resetSelection(),
              child: MusclePickerMap(
                key: _mapKey,
                map: Maps.BODY,
                isEditing: false,
                actAsToggle: true,
                onChanged: _onMapChanged,
                strokeColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                dotColor: Colors.transparent,
                selectedColor: const Color(0xFFE0E0E0),
                width: mapWidth,
                height: mapHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallHistoryView(List<WorkoutHistoryEntry> history) {
    return Card(
      key: const ValueKey('overall_view'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evolução Geral (Volume Total)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: history.isEmpty
                  ? const Center(child: Text('Sem dados de treino para exibir.'))
                  : LineChart(_createChartData(history, 'Volume')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualMuscleHistoryView(String muscleId, List<WorkoutHistoryEntry> fullHistory) {
    final muscleGroup = _getGroupForMuscleId(muscleId);
    final groupHistory = fullHistory.where((s) => s.muscleGroup == muscleGroup).toList();

    return Card(
      key: ValueKey(muscleId),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progressão de Carga: ${muscleGroup.toUpperCase()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: groupHistory.isEmpty
                  ? const Center(child: Text('Sem dados para este músculo.'))
                  : LineChart(_createChartData(groupHistory, 'Carga (kg)')),
            ),
            const Divider(height: 32),
            const Text('Últimos Treinos Registrados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (groupHistory.isEmpty)
              const Text('Nenhum treino registrado para este grupo.')
            else
              ...groupHistory.reversed.take(4).map((session) => ListTile(
                    leading: const Icon(Icons.fitness_center, size: 28),
                    title: Text(session.exerciseName),
                    subtitle: Text('${session.weight} kg x ${session.reps} reps'),
                    trailing: Text(DateFormat('dd/MM').format(session.date)),
                  )),
          ],
        ),
      ),
    );
  }
  
  // ---------- Gráfico com dados reais ----------
  LineChartData _createChartData(List<WorkoutHistoryEntry> history, String yTitle) {
    final Map<DateTime, double> dailyData = {};
    for (var session in history) {
      final day = DateTime(session.date.year, session.date.month, session.date.day);
      final value = (yTitle == 'Volume') ? session.weight * session.reps : session.weight;
      // Pega o maior valor do dia para o gráfico
      if (!dailyData.containsKey(day) || value > dailyData[day]!) {
        dailyData[day] = value;
      }
    }
    final sortedEntries = dailyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final List<FlSpot> spots = List.generate(
      sortedEntries.length,
      (i) => FlSpot(i.toDouble(), sortedEntries[i].value),
    );

    return LineChartData(
      // ... A configuração do LineChartData permanece a mesma de antes ...
      lineTouchData: LineTouchData( /* ... */ ),
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < sortedEntries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd/MM').format(sortedEntries[i].key), style: const TextStyle(fontSize: 10)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _legend({required String title, required List<(String, Color)> items}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: e.$2),
            const SizedBox(width: 4),
            Text(e.$1, style: Theme.of(context).textTheme.bodySmall),
          ],
        )).toList(),
      ),
    ],
  );
}

// Camada visual de calor que não intercepta toques (sem alterações)
class _HeatLayer extends StatelessWidget {
  final Set<String> groups;
  final Color color;
  final double width;
  final double height;
  const _HeatLayer({required this.groups, required this.color, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: MusclePickerMap(
        map: Maps.BODY,
        onChanged: (_) {},
        isEditing: false,
        initialSelectedGroups: groups.toList(),
        selectedColor: groups.isEmpty ? Colors.transparent : color.withOpacity(0.7),
        dotColor: Colors.transparent,
        strokeColor: Colors.transparent,
        width: width,
        height: height,
      ),
    );
  }
}
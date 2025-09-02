// fitapp/lib/screens/muscle_screen.dart
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muscle_selector/muscle_selector.dart';
import 'package:muscle_selector/src/parser.dart';
import '../widgets/app_drawer.dart';

class PlaceholderSession {
  final DateTime date;
  final String exerciseName;
  final String muscleGroup;
  final double weight;
  final int reps;
  PlaceholderSession(this.date, this.exerciseName, this.muscleGroup, this.weight, this.reps);
}

class MuscleScreen extends StatefulWidget {
  const MuscleScreen({super.key});
  @override
  State<MuscleScreen> createState() => _MuscleScreenState();
}

enum MuscleMode { treino, comparativo }

class _MuscleScreenState extends State<MuscleScreen> {
  final GlobalKey<MusclePickerMapState> _mapKey = GlobalKey();
  MuscleMode _mode = MuscleMode.treino;
  String? selectedMuscleId;
  late final List<PlaceholderSession> _placeholderHistory;

  // dicionário de cores para os buckets
  static const Map<String, Color> _bucketColors = {
    'green': Colors.green,
    'yellow': Colors.yellow,
    'red': Colors.red,
    'purple': Color(0xFF4A148C),
  };

  @override
  void initState() {
    super.initState();
    _placeholderHistory = _generatePlaceholderHistoryData();
  }

  // ---------- interação ----------
  void _resetSelection() {
    _mapKey.currentState?.clearSelect();
    setState(() => selectedMuscleId = null);
  }

  void _onMapChanged(Set<Muscle> muscles) {
    if (muscles.isEmpty) {
      setState(() => selectedMuscleId = null);
    } else {
      setState(() => selectedMuscleId = muscles.last.id);
    }
  }

  List<String> _initialGroupsForMap() {
    if (selectedMuscleId == null) return const [];
    final g = _getGroupForMuscleId(selectedMuscleId!);
    return g.isEmpty ? const [] : [g];
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
        ? selectedMuscleId!.replaceAll('_', ' ').split(RegExp(r'(?=\d)')).join(' ').toUpperCase()
        : 'Análise Muscular';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildControls(),
            const SizedBox(height: 12),
            _buildMapWithHeat(mapWidth, mapHeight), // mapa com calor + clique
            const SizedBox(height: 12),
            _legend(
              title: _mode == MuscleMode.treino ? 'Recência de Treino' : 'Nível de Força (Percentil)',
              items: const [
                ('Baixo', Colors.green), ('Médio', Colors.yellow),
                ('Alto', Colors.red), ('Muito Alto', Color(0xFF4A148C)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: selectedMuscleId == null
                  ? _buildOverallHistoryView()
                  : _buildIndividualMuscleHistoryView(selectedMuscleId!),
            ),
          ],
        ),
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

  Widget _buildMapWithHeat(double mapWidth, double mapHeight) {
    final buckets = (_mode == MuscleMode.treino)
        ? _computeRecencyBuckets(days: 14)
        : _computePercentileBuckets();

    return Center(
      child: SizedBox(
        width: mapWidth,
        height: mapHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camadas de calor (apenas visuais, não interceptam toques)
            _HeatLayer(
              groups: buckets['green'] ?? const <String>{},
              color: _bucketColors['green']!,
              width: mapWidth,
              height: mapHeight,
            ),
            _HeatLayer(
              groups: buckets['yellow'] ?? const <String>{},
              color: _bucketColors['yellow']!,
              width: mapWidth,
              height: mapHeight,
            ),
            _HeatLayer(
              groups: buckets['red'] ?? const <String>{},
              color: _bucketColors['red']!,
              width: mapWidth,
              height: mapHeight,
            ),
            _HeatLayer(
              groups: buckets['purple'] ?? const <String>{},
              color: _bucketColors['purple']!,
              width: mapWidth,
              height: mapHeight,
            ),

            // Mapa clicável único por cima
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _resetSelection(),
              child: MusclePickerMap(
                key: _mapKey,
                map: Maps.BODY,
                isEditing: false,
                actAsToggle: true,
                initialSelectedGroups: _initialGroupsForMap(),
                onChanged: _onMapChanged,
                strokeColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                dotColor: Colors.transparent,
                selectedColor: const Color(0xFFE0E0E0), // destaque do selecionado
                width: mapWidth,
                height: mapHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallHistoryView() {
    return Card(
      key: const ValueKey('overall_view'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evolução Geral (Volume Total)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(_createChartData(_placeholderHistory, 'Volume')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualMuscleHistoryView(String muscleId) {
    final muscleGroup = _getGroupForMuscleId(muscleId);
    final groupHistory =
        _placeholderHistory.where((s) => s.muscleGroup == muscleGroup).toList();

    return Card(
      key: ValueKey(muscleId),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progressão de Carga: ${muscleGroup.toUpperCase()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(_createChartData(groupHistory, 'Carga (kg)')),
            ),
            const Divider(height: 32),
            const Text('Últimos Treinos Registrados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // ---------- dados fictícios ----------
  List<PlaceholderSession> _generatePlaceholderHistoryData() {
    final now = DateTime.now();
    return [
      PlaceholderSession(now.subtract(const Duration(days: 30)), 'Supino Reto', 'chest', 80, 8),
      PlaceholderSession(now.subtract(const Duration(days: 28)), 'Agachamento', 'quads', 100, 6),
      PlaceholderSession(now.subtract(const Duration(days: 25)), 'Remada Curvada', 'lats', 70, 10),
      PlaceholderSession(now.subtract(const Duration(days: 23)), 'Supino Reto', 'chest', 82.5, 7),
      PlaceholderSession(now.subtract(const Duration(days: 21)), 'Agachamento', 'quads', 105, 5),
      PlaceholderSession(now.subtract(const Duration(days: 18)), 'Barra Fixa', 'lats', 0, 8),
      PlaceholderSession(now.subtract(const Duration(days: 16)), 'Supino Reto', 'chest', 82.5, 8),
      PlaceholderSession(now.subtract(const Duration(days: 14)), 'Agachamento', 'quads', 105, 6),
      PlaceholderSession(now.subtract(const Duration(days: 11)), 'Rosca Direta', 'biceps', 18, 10),
      PlaceholderSession(now.subtract(const Duration(days: 9)), 'Supino Reto', 'chest', 85, 6),
      PlaceholderSession(now.subtract(const Duration(days: 7)), 'Agachamento', 'quads', 110, 5),
      PlaceholderSession(now.subtract(const Duration(days: 4)), 'Rosca Direta', 'biceps', 20, 8),
      PlaceholderSession(now.subtract(const Duration(days: 2)), 'Supino Reto', 'chest', 85, 7),
    ];
  }

  // ---------- gráfico ----------
  LineChartData _createChartData(List<PlaceholderSession> history, String yTitle) {
    final Map<DateTime, double> dailyData = {};
    for (var session in history) {
      final day = DateTime(session.date.year, session.date.month, session.date.day);
      final value = (yTitle == 'Volume') ? session.weight * session.reps : session.weight;
      if (!dailyData.containsKey(day) || value > dailyData[day]!) {
        dailyData[day] = value;
      }
    }
    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final List<FlSpot> spots = List.generate(
      sortedEntries.length,
      (i) => FlSpot(i.toDouble(), sortedEntries[i].value),
    );

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (LineBarSpot s) => Colors.blueGrey.withOpacity(0.8),
          getTooltipItems: (touchedSpots) => touchedSpots
              .map((barSpot) => LineTooltipItem(
                    '${barSpot.y.toStringAsFixed(1)} ${yTitle == "Volume" ? "" : "kg"}',
                    TextStyle(
                      color: Theme.of(context).canvasColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ))
              .toList(),
        ),
      ),
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: (yTitle == 'Volume' ? 200 : 10),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < sortedEntries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(sortedEntries[i].key),
                    style: const TextStyle(fontSize: 10),
                  ),
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
          spots: spots.isEmpty ? [FlSpot(0, 0)] : spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  // ---------- buckets placeholder ----------
  Map<String, Set<String>> _computeRecencyBuckets({required int days}) {
    return {
      'green': {'calves', 'biceps'},
      'yellow': {'chest', 'delts'},
      'red': {'quads', 'glutes'},
      'purple': {'lats', 'hamstrings'}
    };
  }

  Map<String, Set<String>> _computePercentileBuckets() {
    return {
      'green': {'triceps', 'lower_back', 'obliques'},
      'yellow': {'traps', 'calves', 'forearm'},
      'red': {'biceps', 'chest', 'abs'},
      'purple': {'quads', 'glutes', 'adductors'}
    };
  }

  Widget _legend({required String title, required List<(String, Color)> items}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((e) => Chip(avatar: CircleAvatar(backgroundColor: e.$2), label: Text(e.$1))).toList(),
      ),
    ],
  );
}

// Camada visual de calor que não intercepta toques
class _HeatLayer extends StatelessWidget {
  final Set<String> groups;
  final Color color;
  final double width;
  final double height;
  const _HeatLayer({required this.groups, required this.color, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final map = MusclePickerMap(
      map: Maps.BODY,
      onChanged: (muscles) {},
      isEditing: false,
      initialSelectedGroups: groups.toList(),
      selectedColor: groups.isEmpty ? Colors.transparent : color,
      dotColor: Colors.transparent,
      strokeColor: Colors.black26,
      width: width,
      height: height,
    );
    return IgnorePointer(child: map);
  }
}

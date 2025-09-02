import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:muscle_selector/muscle_selector.dart';

/// Tela: mapa muscular com 2 modos (Treino / Comparativo)
/// - Usa muscle_selector empilhado por buckets de cor
/// - Top transparente capta cliques (isEditing: true) e abre detalhes
class MuscleScreen extends StatefulWidget {
  const MuscleScreen({super.key});
  @override
  State<MuscleScreen> createState() => _MuscleScreenState();
}

enum MuscleMode { treino, comparativo }

class _MuscleScreenState extends State<MuscleScreen> {
  MuscleMode _mode = MuscleMode.treino;
  bool _front = true; // opcional se você alternar frente/costas na lib
  late final Map<String, String> _ptToLib; // mapeia PT -> grupos da lib

  @override
  void initState() {
    super.initState();
    _ptToLib = _buildPtToLibMap();
  }

  @override
  Widget build(BuildContext context) {
    final gender = Hive.box('profile').get('gender', defaultValue: 'M'); // 'M' ou 'F'
    final size = MediaQuery.of(context).size;
    final mapWidth = min(420.0, size.width - 32);
    final mapHeight = mapWidth * 1.15;

    // Conjuntos de grupos por bucket de cor
    final buckets = (_mode == MuscleMode.treino)
        ? _computeRecencyBuckets(days: 14)
        : _computePercentileBuckets(gender: gender);

    final green = buckets['green'] ?? const <String>{};
    final yellow = buckets['yellow'] ?? const <String>{};
    final red = buckets['red'] ?? const <String>{};
    final purple = buckets['purple'] ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Muscular'),
        actions: [
          // alternar modo
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<MuscleMode>(
              segments: const [
                ButtonSegment(value: MuscleMode.treino, icon: Icon(Icons.whatshot), label: Text('Treino')),
                ButtonSegment(value: MuscleMode.comparativo, icon: Icon(Icons.bar_chart), label: Text('Comparativo')),
              ],
              selected: <MuscleMode>{_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _HeatLayer(groups: green, color: Colors.green, width: mapWidth, height: mapHeight),
                _HeatLayer(groups: yellow, color: Colors.yellow.shade700, width: mapWidth, height: mapHeight),
                _HeatLayer(groups: red, color: Colors.red.shade600, width: mapWidth, height: mapHeight),
                _HeatLayer(groups: purple, color: const Color(0xFF4A148C), width: mapWidth, height: mapHeight),

                // Mapa “invisível” para captar cliques (sem cor/sem stroke visível)
                IgnorePointer(
                  ignoring: false,
                  child: Opacity(
                    opacity: 0.001, // praticamente invisível
                    child: MusclePickerMap(
                      map: Maps.BODY, // a lib expõe esse enum; sem opção por sexo
                      isEditing: true,
                      initialSelectedGroups: const [],
                      onChanged: (muscles) {
                        // quando o usuário toca, a lib alterna seleção; pegue o último selecionado
                        if (muscles.isEmpty) return;
                        final last = muscles.last;
                        final group = last.group; // nome do grupo (em inglês)
                        _showMuscleDetails(context, group);
                      },
                      actAsToggle: true,
                      width: mapWidth,
                      height: mapHeight,
                      selectedColor: Colors.transparent,
                      dotColor: Colors.transparent,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _mode == MuscleMode.treino
              ? _legend(
                  title: 'Recência (últimos 14 dias)',
                  items: const [
                    ('Treinou há bastante', Colors.green),
                    ('Meia recência', Colors.yellow),
                    ('Recente', Colors.red),
                    ('Muito recente', Color(0xFF4A148C)),
                  ],
                )
              : _legend(
                  title: 'Comparativo (percentis de força)',
                  items: const [
                    ('Iniciante / Abaixo', Colors.green),
                    ('Médio', Colors.yellow),
                    ('Avançado', Colors.red),
                    ('Elite (topo)', Color(0xFF4A148C)),
                  ],
                ),
          const SizedBox(height: 8),
          Text(
            _mode == MuscleMode.treino
                ? 'As cores refletem o quão recente você treinou cada grupo (14 dias).'
                : 'As cores refletem seu nível relativo estimado por grupo (percentis).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ==== Helpers de UI ====

  Widget _legend({required String title, required List<(String, Color)> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((e) => Chip(
                    avatar: CircleAvatar(backgroundColor: e.$2),
                    label: Text(e.$1),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _showMuscleDetails(BuildContext ctx, String libGroup) async {
    // lista simples: últimas sessões com exercícios que batem nesse grupo
    final items = _recentExerciseFactsForGroup(libGroup);
    if (!ctx.mounted) return;
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 380,
          child: items.isEmpty
              ? const Center(child: Text('Sem registros recentes para esse grupo.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    return ListTile(
                      title: Text(m['exercise'] as String),
                      subtitle: Text('${m['date']} — ${m['hint']}'),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ==== Cálculos de dados ====

  /// Buckets de recência: green/yellow/red/purple (mais antigo → mais recente)
  Map<String, Set<String>> _computeRecencyBuckets({required int days}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final sessions = Hive.box('sessions').values.cast<Map>().toList();
    final exBox = Hive.box('exercises');

    // último treino por grupo
    final lastTrain = <String, DateTime>{};

    for (final s in sessions) {
      final dateStr = (s['date'] ?? '') as String;
      if (dateStr.isEmpty) continue;
      final d = DateTime.tryParse(dateStr) ?? DateTime.now();
      if (d.isBefore(since)) continue;

      final entries = (s['exercises'] ?? s['items'] ?? s['results']) as List?;
      if (entries == null) continue;

      for (final it in entries) {
        final m = Map<String, dynamic>.from(it as Map);
        final exId = (m['exerciseId'] ?? m['id'] ?? '').toString();
        if (exId.isEmpty) continue;
        final ex = exBox.get(exId) as Map?;
        if (ex == null) continue;

        final groups = _groupsForExercise(ex);
        for (final g in groups) {
          final prev = lastTrain[g];
          if (prev == null || d.isAfter(prev)) lastTrain[g] = d;
        }
      }
    }

    // bucketização
    final green = <String>{};
    final yellow = <String>{};
    final red = <String>{};
    final purple = <String>{};

    final now = DateTime.now();
    lastTrain.forEach((group, dt) {
      final diff = now.difference(dt).inDays.toDouble();
      if (diff >= 10) {
        green.add(group);
      } else if (diff >= 6) {
        yellow.add(group);
      } else if (diff >= 3) {
        red.add(group);
      } else {
        purple.add(group);
      }
    });

    return {'green': green, 'yellow': yellow, 'red': red, 'purple': purple};
  }

  /// Buckets por percentil (usa melhor 1RM/reps salvos no profile)
  Map<String, Set<String>> _computePercentileBuckets({required String gender}) {
    // percentis previamente calculados e salvos? Se não, estimamos a partir do profile (simples)
    final profile = Hive.box('profile');

    double? pSup = (profile.get('p_supino') as num?)?.toDouble();
    double? pSqt = (profile.get('p_agachamento') as num?)?.toDouble();
    double? pDl = (profile.get('p_terra') as num?)?.toDouble();
    double? pPu = (profile.get('p_barra_fixa') as num?)?.toDouble();

    // fallback básico caso não tenha percentis salvos
    pSup ??= 50;
    pSqt ??= 50;
    pDl ??= 50;
    pPu ??= 50;

    // mapeia percentil para grupos
    final mapP = <String, double>{
      'chest': pSup,
      'delts': pSup,
      'triceps': pSup,
      'quads': pSqt,
      'glutes': max(pSqt, pDl),
      'lower_back': pDl,
      'hamstrings': pDl,
      'lats': pPu,
      'biceps': pPu,
      // outros grupos podem ser adicionados conforme seu dataset crescer
    };

    final green = <String>{};
    final yellow = <String>{};
    final red = <String>{};
    final purple = <String>{};

    mapP.forEach((group, p) {
      if (p < 40) {
        green.add(group);
      } else if (p < 60) {
        yellow.add(group);
      } else if (p < 90) {
        red.add(group);
      } else {
        purple.add(group);
      }
    });

    return {'green': green, 'yellow': yellow, 'red': red, 'purple': purple};
  }

  /// Extrai grupos (em inglês, usados pela lib) para um exercício
  Set<String> _groupsForExercise(Map ex) {
    final prim = (ex['primary'] as List?)?.cast<String>() ?? const <String>[];
    final sec = (ex['secondary'] as List?)?.cast<String>() ?? const <String>[];
    final all = <String>{...prim, ...sec};
    final libGroups = <String>{};

    for (final pt in all) {
      final g = _ptToLib[pt.toLowerCase().trim()];
      if (g != null && g.isNotEmpty) libGroups.add(g);
    }
    return libGroups;
  }

  /// Lista simples para o bottom sheet
  List<Map<String, String>> _recentExerciseFactsForGroup(String libGroup) {
    final exBox = Hive.box('exercises');
    final sessions = Hive.box('sessions').values.cast<Map>().toList().reversed; // mais recentes primeiro
    final out = <Map<String, String>>[];

    for (final s in sessions) {
      final dateStr = (s['date'] ?? '') as String;
      final entries = (s['exercises'] ?? s['items'] ?? s['results']) as List?;
      if (entries == null) continue;

      for (final it in entries) {
        final m = Map<String, dynamic>.from(it as Map);
        final exId = (m['exerciseId'] ?? m['id'] ?? '').toString();
        if (exId.isEmpty) continue;
        final ex = exBox.get(exId) as Map?;
        if (ex == null) continue;
        final groups = _groupsForExercise(ex);
        if (!groups.contains(libGroup)) continue;

        final name = (ex['name'] ?? exId).toString();
        // cria um "hint" simples (peso×reps / distância/tempo se houver)
        String hint = '';
        if (m['weight'] != null && m['reps'] != null) {
          hint = '${m['weight']} kg × ${m['reps']}';
        } else if (m['distance'] != null || m['time'] != null) {
          final d = m['distance']; final t = m['time'];
          if (d != null && t != null) {
            hint = '${d}km em ${t}min';
          } else if (d != null) {
            hint = '${d}km';
          } else {
            hint = '${t}min';
          }
        } else {
          hint = 'registrado';
        }
        out.add({'date': dateStr, 'exercise': name, 'hint': hint});
        if (out.length >= 12) return out; // limita
      }
    }
    return out;
  }

  Map<String, String> _buildPtToLibMap() {
    return {
      // peito / ombro / braço
      'peitoral': 'chest',
      'deltoide_anterior': 'delts',
      'deltoide lateral': 'delts',
      'deltoide': 'delts',
      'tríceps': 'triceps',
      'triceps': 'triceps',
      'bíceps': 'biceps',
      'biceps': 'biceps',

      // costas / núcleo
      'dorsal': 'lats',
      'lombar': 'lower_back',
      'trapézio': 'traps',
      'trapézio superior': 'traps',

      // pernas
      'quadríceps': 'quads',
      'quadriceps': 'quads',
      'posterior_coxa': 'hamstrings',
      'isquiotibiais': 'hamstrings',
      'glúteos': 'glutes',
      'gluteos': 'glutes',
      'panturrilhas': 'calves',
      'panturrilha': 'calves',
      // cardio “não mapeia” para grupos; ignoramos
      'cardio': '',
    };
  }
}

/// Uma camada do heatmap (apenas os grupos desse bucket com uma cor)
class _HeatLayer extends StatelessWidget {
  final Set<String> groups;
  final Color color;
  final double width;
  final double height;
  const _HeatLayer({required this.groups, required this.color, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      // ainda assim renderizamos a base p/ manter tamanho
      return MusclePickerMap(
        map: Maps.BODY,
        isEditing: false,
        initialSelectedGroups: const [],
        selectedColor: Colors.transparent,
        dotColor: Colors.transparent,
        strokeColor: Colors.black26,
        width: width,
        height: height,
      );
    }
    return MusclePickerMap(
      map: Maps.BODY,
      isEditing: false,
      initialSelectedGroups: groups.toList(),
      selectedColor: color,
      dotColor: Colors.transparent,
      strokeColor: Colors.black26,
      width: width,
      height: height,
    );
  }
}

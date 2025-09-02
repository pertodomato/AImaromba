import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../services/ai/session_prompt_service.dart';
import '../widgets/app_drawer.dart';

class TrainSessionsScreen extends StatefulWidget {
  const TrainSessionsScreen({super.key});
  @override
  State<TrainSessionsScreen> createState() => _TrainSessionsScreenState();
}

class _TrainSessionsScreenState extends State<TrainSessionsScreen> {
  @override
  Widget build(BuildContext context) {
    final blocksBox = Hive.box('blocks');
    final sessions = blocksBox.values.map((e) => Map<String, dynamic>.from(e)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sessões de Treino')),
      drawer: const AppNavDrawer(),
      body: ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (_, i) {
          final b = sessions[i];
          final id = b['id'];
          final name = (b['name'] ?? 'Sessão').toString();
          final exercises = (b['exercises'] as List? ?? const []).length;
          final dur = (b['estimatedDurationMin'] ?? 0).toString();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              title: Text(name),
              subtitle: Text('Exercícios: $exercises — $dur min'),
              onTap: () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _EditSessionDialog(block: b),
                );
                if (mounted) setState(() {});
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Iniciar',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => context.go('/workout/$id'),
                  ),
                  IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Excluir sessão?'),
                          content: const Text('Esta ação não pode ser desfeita.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        blocksBox.delete(id);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _CreateSessionDialog(),
          );
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova sessão'),
      ),
    );
  }
}

/// ==================== DIALOG BASE (sem overflow / responsivo) ====================

class _BaseDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  const _BaseDialog({required this.title, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final maxW = (screen.width * 0.94).clamp(360.0, 720.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleLarge!,
                child: Align(alignment: Alignment.centerLeft, child: title),
              ),
              const SizedBox(height: 12),
              // Flexible + SingleChildScrollView evitam "no size" e overflow
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: content,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==================== CREATE DIALOG ====================

class _CreateSessionDialog extends StatefulWidget {
  const _CreateSessionDialog();
  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  final _textCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _draft; // block
  final List<_ItemDraft> _items = [];

  Future<void> _generate() async {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descreva a sessão.')));
      return;
    }
    setState(() {
      _loading = true;
      _draft = null;
      _items.clear();
    });

    final res = await SessionPromptService.generateWorkoutDraftFromText(t);
    if (!mounted) return;

    if (res == null || res['block'] == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao gerar com IA. Verifique a API key em Perfil.')),
      );
      return;
    }

    final block = Map<String, dynamic>.from(res['block']);
    for (final it in (block['exercises'] as List)) {
      _items.add(_ItemDraft.fromMap(Map<String, dynamic>.from(it)));
    }
    setState(() {
      _draft = block;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_draft == null) return;
    final block = {
      'id': _draft!['id'],
      'name': _draft!['name'],
      'estimatedDurationMin': _draft!['estimatedDurationMin'],
      'exercises': _items.map((e) => e.toBlockItem()).toList(),
    };
    Hive.box('blocks').put(block['id'], block);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: const Text('Criar sessão por IA'),
      content: _loading
          ? const _LoadingPane()
          : (_draft == null ? _InputPane(controller: _textCtrl) : _EditorPane(items: _items)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (_draft == null)
          ElevatedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Criar'),
          ),
        if (_draft != null)
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Salvar'),
          ),
      ],
    );
  }
}

/// ==================== EDIT DIALOG ====================

class _EditSessionDialog extends StatefulWidget {
  final Map<String, dynamic> block;
  const _EditSessionDialog({required this.block});
  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late List<_ItemDraft> _items;

  @override
  void initState() {
    super.initState();
    _items = [];
    for (final it in (widget.block['exercises'] as List? ?? const [])) {
      _items.add(_ItemDraft.fromMap(Map<String, dynamic>.from(it)));
    }
  }

  Future<void> _save() async {
    final block = Map<String, dynamic>.from(widget.block);
    block['exercises'] = _items.map((e) => e.toBlockItem()).toList();
    Hive.box('blocks').put(block['id'], block);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: Text(widget.block['name'] ?? 'Sessão'),
      content: _EditorPane(items: _items),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Salvar')),
      ],
    );
  }
}

/// ==================== SUB-WIDGETS ====================

class _InputPane extends StatelessWidget {
  final TextEditingController controller;
  const _InputPane({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Descreva a sessão (o modelo estima nome, duração, etc).'),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: 6,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText:
              'Peito/ombros/bíceps — 50–60 min. Usar supino da biblioteca + 2 exercícios coerentes. '
              '4 séries/8–10 reps no principal (progressão por peso) e 90s de descanso.',
        ),
      ),
    ]);
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Gerando com IA…'),
        ]),
      ),
    );
  }
}

class _EditorPane extends StatefulWidget {
  final List<_ItemDraft> items;
  const _EditorPane({required this.items});
  @override
  State<_EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<_EditorPane> {
  List<String> _metricsForExercise(String exerciseId) {
    final ex = Hive.box('exercises').get(exerciseId);
    final out = <String>[];
    if (ex != null && ex['metrics'] is Map) {
      Map<String, dynamic>.from(ex['metrics']).forEach((k, v) {
        if (v == true) out.add(k);
      });
    }
    if (out.contains('time') && !out.contains('timeSec')) out.add('timeSec');
    if (out.contains('distance') && !out.contains('distanceKm')) out.add('distanceKm');
    out.add('(custom)');
    return out.toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const Text('Nada para editar.');

    // IMPORTANTE: shrinkWrap + physics = embed dentro do Scroll do diálogo (sem overflow)
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final it = widget.items[i];
        final ex = Hive.box('exercises').get(it.exerciseId);
        final exName = (ex?['name'] ?? it.exerciseId).toString();
        final metrics = _metricsForExercise(it.exerciseId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(exName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Campos básicos (quebram linha automaticamente)
              Wrap(spacing: 8, runSpacing: 8, children: [
                _numField('Séries', it.sets?.toString() ?? '', (v) => it.sets = int.tryParse(v), width: 110),
                _textField('Repetições (ex.: 8-10)', it.reps ?? '', (v) => it.reps = v.isEmpty ? null : v, width: 170),
                _numField('Descanso (s)', it.restSec?.toString() ?? '', (v) => it.restSec = int.tryParse(v), width: 140),
                _numField('Tempo (s)', it.timeSec?.toString() ?? '', (v) => it.timeSec = int.tryParse(v), width: 130),
                _numField('Distância (km)', it.distanceKm?.toString() ?? '', (v) => it.distanceKm = double.tryParse(v), width: 150),
                _numField('Velocidade (km/h)', it.speedKmh?.toString() ?? '', (v) => it.speedKmh = double.tryParse(v), width: 160),
                _numField('Inclinação (%)', it.gradientPercent?.toString() ?? '', (v) => it.gradientPercent = double.tryParse(v), width: 150),
              ]),

              const SizedBox(height: 8),

              // Progressão (duas colunas responsivas)
              _ResponsiveTwoCols(
                left: DropdownButtonFormField<String>(
                  isDense: true,
                  value: metrics.contains(it.progressMetric) ? it.progressMetric : metrics.first,
                  items: metrics.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => it.progressMetric = v ?? it.progressMetric),
                  decoration: const InputDecoration(labelText: 'Métrica de progressão', isDense: true),
                ),
                right: DropdownButtonFormField<String>(
                  isDense: true,
                  value: it.strategy,
                  items: const [
                    DropdownMenuItem(value: 'linear', child: Text('linear')),
                    DropdownMenuItem(value: 'double_progression', child: Text('double_progression')),
                    DropdownMenuItem(value: 'rpe', child: Text('rpe')),
                    DropdownMenuItem(value: 'interval', child: Text('interval')),
                  ],
                  onChanged: (v) => setState(() => it.strategy = v ?? 'linear'),
                  decoration: const InputDecoration(labelText: 'Estratégia', isDense: true),
                ),
              ),

              const SizedBox(height: 8),

              // Parâmetros (empilham se faltar largura)
              Wrap(spacing: 8, runSpacing: 8, children: [
                _numField('Passo (step)', it.step?.toString() ?? '', (v) => it.step = double.tryParse(v), width: 130),
                _numField('min reps', it.minReps?.toString() ?? '', (v) => it.minReps = int.tryParse(v), width: 110),
                _numField('max reps', it.maxReps?.toString() ?? '', (v) => it.maxReps = int.tryParse(v), width: 110),
              ]),

              const SizedBox(height: 8),

              TextFormField(
                initialValue: it.notes ?? '',
                decoration: const InputDecoration(labelText: 'Notas de progressão', isDense: true),
                onChanged: (v) => it.notes = v,
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _numField(String label, String init, void Function(String) onChanged, {double width = 120}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: init,
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      ),
    );
  }

  Widget _textField(String label, String init, void Function(String) onChanged, {double width = 160}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: init,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}

/// 2 colunas que viram 1 em telas estreitas
class _ResponsiveTwoCols extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;
  const _ResponsiveTwoCols({required this.left, required this.right, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final narrow = c.maxWidth < 520;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, SizedBox(height: gap), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: left), SizedBox(width: gap), Expanded(child: right)],
        );
      },
    );
  }
}

/// ===== Item draft =====
class _ItemDraft {
  String exerciseId;
  String? reps;
  int? sets;
  int? restSec;
  int? timeSec;
  double? distanceKm;
  double? speedKmh;
  double? gradientPercent;

  String progressMetric;
  String strategy;
  double? step;
  int? minReps;
  int? maxReps;
  String? notes;

  _ItemDraft({
    required this.exerciseId,
    this.reps,
    this.sets,
    this.restSec,
    this.timeSec,
    this.distanceKm,
    this.speedKmh,
    this.gradientPercent,
    this.progressMetric = 'reps',
    this.strategy = 'linear',
    this.step,
    this.minReps,
    this.maxReps,
    this.notes,
  });

  factory _ItemDraft.fromMap(Map<String, dynamic> m) {
    final prog = Map<String, dynamic>.from(m['progression'] ?? {});
    return _ItemDraft(
      exerciseId: (m['exerciseId'] ?? '').toString(),
      reps: (m['reps'] as String?) ?? m['reps']?.toString(),
      sets: (m['sets'] as num?)?.toInt(),
      restSec: (m['restSec'] as num?)?.toInt(),
      timeSec: (m['timeSec'] as num?)?.toInt(),
      distanceKm: (m['distanceKm'] as num?)?.toDouble(),
      speedKmh: (m['speedKmh'] as num?)?.toDouble(),
      gradientPercent: (m['gradientPercent'] as num?)?.toDouble(),
      progressMetric: (prog['metric'] ?? 'reps').toString(),
      strategy: (prog['strategy'] ?? 'linear').toString(),
      step: (prog['step'] as num?)?.toDouble(),
      minReps: (prog['minReps'] as num?)?.toInt(),
      maxReps: (prog['maxReps'] as num?)?.toInt(),
      notes: prog['notes']?.toString(),
    );
  }

  Map<String, dynamic> toBlockItem() => {
        'exerciseId': exerciseId,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
        if (restSec != null) 'restSec': restSec,
        if (timeSec != null) 'timeSec': timeSec,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (speedKmh != null) 'speedKmh': speedKmh,
        if (gradientPercent != null) 'gradientPercent': gradientPercent,
        'progression': {
          'metric': progressMetric,
          'strategy': strategy,
          if (step != null) 'step': step,
          if (minReps != null) 'minReps': minReps,
          if (maxReps != null) 'maxReps': maxReps,
          if (notes != null && notes!.isNotEmpty) 'notes': notes,
        },
      };
}

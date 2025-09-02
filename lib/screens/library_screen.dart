import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitapp/services/ai/exercise_prompt_service.dart';
import '../widgets/app_drawer.dart'; // + import

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '';

  Future<void> _openEditor({Map<String, dynamic>? exercise}) async {
    final Map<String, dynamic>? result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExerciseEditorDialog(
        initial: exercise,
        mode: exercise == null ? EditorMode.create : EditorMode.edit,
      ),
    );
    if (result == null) return;
    final box = Hive.box('exercises');

    // garante id único
    var id = (result['id'] ?? '').toString();
    if (id.isEmpty) {
      id = _genId(result['name'] ?? 'exercicio');
      result['id'] = id;
    }
    if (box.containsKey(id)) {
      id = '${id}_${DateTime.now().millisecondsSinceEpoch}';
      result['id'] = id;
    }
    box.put(id, result);
    setState(() {});
  }

  String _genId(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('exercises');
    final list = box.values.where((e) {
      if (query.isEmpty) return true;
      return (e['name'] as String).toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de Exercícios')),
      drawer: const AppNavDrawer(), // <-- ADICIONE
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar'),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = Map<String, dynamic>.from(list[i]);
              return Card(
                child: ListTile(
                  title: Text(e['name'] ?? ''),
                  subtitle: Text('Primário: ${(e['primary'] as List).join(', ')}'),
                  onTap: () => _openEditor(exercise: e),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Duplicar',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          final newId = '${e['id']}_copy_${DateTime.now().millisecondsSinceEpoch}';
                          final ne = Map<String, dynamic>.from(e)
                            ..['id'] = newId
                            ..['name'] = '${e['name']} (cópia)';
                          box.put(newId, ne);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openEditor(exercise: e),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(), // fluxo IA → loading → form
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ====== Dialog ======
enum EditorMode { create, edit }
enum EditorStage { iaInput, iaLoading, form }

class ExerciseEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final EditorMode mode;
  const ExerciseEditorDialog({super.key, this.initial, required this.mode});

  @override
  State<ExerciseEditorDialog> createState() => _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends State<ExerciseEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  // stage
  late EditorStage _stage;

  // campos (ID oculto)
  String _id = '';
  final _nameCtrl = TextEditingController(text: 'Novo exercício');
  String _type = 'strength';

  // métricas
  static const Set<String> _stdMetrics = {'weight','reps','restSec','distance','time'};
  final Set<String> _knownMetricKeys = {..._stdMetrics}; // preenchido pelo DB
  final Set<String> _selectedExtraMetrics = {}; // selecionadas que não são padrão
  bool mWeight = true, mReps = true, mRest = true, mDistance = false, mTime = false;
  final _newMetricCtrl = TextEditingController();

  // músculos e met
  final _primaryCtrl = TextEditingController();
  final _secondaryCtrl = TextEditingController();
  final _metCtrl = TextEditingController(text: '6.0');

  // JSON raw (opcional)
  final _rawJsonCtrl = TextEditingController();
  bool _showJson = false;

  // IA
  final _iaTextCtrl = TextEditingController();
  bool _iaBusy = false;

  @override
  void initState() {
    super.initState();
    _loadKnownMetricsFromDb();
    if (widget.mode == EditorMode.edit && widget.initial != null) {
      _stage = EditorStage.form;
      _fillFormFromJson(Map<String, dynamic>.from(widget.initial!));
    } else {
      _stage = EditorStage.iaInput; // criar começa pela IA
    }
  }

  void _loadKnownMetricsFromDb() {
    // junta todas as chaves metrics dos exercícios do DB
    final exBox = Hive.box('exercises');
    final s = <String>{..._stdMetrics};
    for (final v in exBox.values) {
      if (v is Map && v['metrics'] is Map) {
        s.addAll(Map<String, dynamic>.from(v['metrics']).keys);
      }
    }
    setState(() {
      _knownMetricKeys
        ..clear()
        ..addAll(s);
    });
  }

  String _genId(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  bool _isMetricSelected(String k) {
    switch (k) {
      case 'weight': return mWeight;
      case 'reps': return mReps;
      case 'restSec': return mRest;
      case 'distance': return mDistance;
      case 'time': return mTime;
      default: return _selectedExtraMetrics.contains(k);
    }
  }

  void _toggleMetric(String k, bool v) {
    setState(() {
      switch (k) {
        case 'weight':   mWeight = v; break;
        case 'reps':     mReps = v; break;
        case 'restSec':  mRest = v; break;
        case 'distance': mDistance = v; break;
        case 'time':     mTime = v; break;
        default:
          if (v) {
            _selectedExtraMetrics.add(k);
          } else {
            _selectedExtraMetrics.remove(k);
          }
      }
      _syncRawJsonFromForm();
    });
  }

  Map<String, dynamic> _buildJsonFromForm() {
    final primary = _primaryCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final secondary = _secondaryCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final metrics = <String, bool>{
      'weight': mWeight,
      'reps': mReps,
      'restSec': mRest,
      'distance': mDistance,
      'time': mTime,
      for (final k in _selectedExtraMetrics) k: true,
    };
    return {
      'id': _id,
      'name': _nameCtrl.text,
      'type': _type,
      'metrics': metrics,
      'primary': primary,
      'secondary': secondary,
      'met': double.tryParse(_metCtrl.text) ?? 6.0,
    };
  }

  void _syncRawJsonFromForm() {
    _rawJsonCtrl.text = const JsonEncoder.withIndent('  ').convert(_buildJsonFromForm());
  }

  void _fillFormFromJson(Map<String, dynamic> m) {
    // ID oculto
    final mid = (m['id'] ?? '').toString();
    _id = mid.isEmpty ? _genId((m['name'] ?? 'exercicio').toString()) : mid;

    if (m['name'] is String) _nameCtrl.text = m['name'];
    final t = (m['type'] ?? 'strength').toString();
    _type = (t == 'cardio' || t == 'isometric' || t == 'stretch') ? t : 'strength';

    // métricas
    final metrics = Map<String, dynamic>.from(m['metrics'] ?? {});
    mWeight   = metrics['weight'] == true;
    mReps     = metrics['reps'] == true;
    mRest     = metrics['restSec'] == true;
    mDistance = metrics['distance'] == true;
    mTime     = metrics['time'] == true;

    _selectedExtraMetrics
      ..clear()
      ..addAll(metrics.entries
          .where((e) => !_stdMetrics.contains(e.key) && e.value == true)
          .map((e) => e.key));

    // garantir que _knownMetricKeys contenha tudo visto
    _knownMetricKeys.addAll(metrics.keys);

    _primaryCtrl.text   = (m['primary'] as List?)?.join(', ') ?? _primaryCtrl.text;
    _secondaryCtrl.text = (m['secondary'] as List?)?.join(', ') ?? _secondaryCtrl.text;
    _metCtrl.text       = '${(m['met'] ?? double.tryParse(_metCtrl.text) ?? 6.0)}';

    _syncRawJsonFromForm();
    setState(() {});
  }

  Future<void> _generateAndOpenForm() async {
    if (_iaBusy) return;
    setState(() { _iaBusy = true; _stage = EditorStage.iaLoading; });
    try {
      final res = await ExercisePromptService.generateExerciseFromText(_iaTextCtrl.text.trim());
      if (!mounted) return;
      if (res == null) {
        setState(() { _stage = EditorStage.iaInput; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao gerar com IA. Verifique a API key em Perfil.')),
        );
      } else {
        res['id'] ??= _genId(res['name'] ?? 'exercicio');
        _fillFormFromJson(res);
        setState(() { _stage = EditorStage.form; });
      }
    } finally {
      if (mounted) setState(() => _iaBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == EditorMode.create;
    final primaryLabel = _stage == EditorStage.form ? 'Salvar' : 'Criar';

    return AlertDialog(
      title: Text(isCreate ? 'Novo exercício' : 'Editar exercício'),
      content: SizedBox(
        width: 560,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_stage) {
            EditorStage.iaInput   => _iaInput(),
            EditorStage.iaLoading => _loading(),
            EditorStage.form      => _form(),
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (!isCreate && _stage == EditorStage.form)
          TextButton(
            onPressed: () async {
              final ok = await _confirmDelete();
              if (!ok) return;
              Hive.box('exercises').delete(_id);
              if (mounted) Navigator.pop(context, null);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: () async {
            if (_stage != EditorStage.form) {
              await _generateAndOpenForm(); // Criar → IA → loading → form
              return;
            }
            if (!_formKey.currentState!.validate()) return;
            final data = _buildJsonFromForm();
            Navigator.pop(context, data);
          },
          child: Text(primaryLabel),
        ),
      ],
    );
  }

  /// ===== UI: etapas =====

  Widget _iaInput() {
    return Column(
      key: const ValueKey('iaInput'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Descreva o exercício (ex.: "Esteira com inclinação 3%, medir distância e tempo; descanso opcional").'),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: TextField(
            controller: _iaTextCtrl,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Digite aqui…'),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Ao clicar em "Criar", gero o JSON com gpt-5-mini e abro o formulário preenchido.'),
      ],
    );
  }

  Widget _loading() {
    return SizedBox(
      key: const ValueKey('loading'),
      height: 220,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(height: 12),
          Text('Gerando com IA…'),
        ]),
      ),
    );
  }

  Widget _form() {
    // ordena métricas: padrão primeiro, depois alfabéticas
    final others = _knownMetricKeys.difference(_stdMetrics).toList()..sort();
    final orderedKeys = [..._stdMetrics, ...others];

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        key: const ValueKey('form'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
            onChanged: (_) => _syncRawJsonFromForm(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'strength', child: Text('Força (strength)')),
              DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
              DropdownMenuItem(value: 'isometric', child: Text('Isométrico')),
              DropdownMenuItem(value: 'stretch', child: Text('Alongamento')),
            ],
            onChanged: (v) { setState(() => _type = v ?? 'strength'); _syncRawJsonFromForm(); },
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          const SizedBox(height: 10),

          const Text('Métricas registradas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: -8,
            children: [
              for (final k in orderedKeys)
                FilterChip(
                  label: Text(k),
                  selected: _isMetricSelected(k),
                  onSelected: (v) => _toggleMetric(k, v),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newMetricCtrl,
            decoration: InputDecoration(
              labelText: 'Adicionar métrica (ex.: incline, rounds, cadence)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final k = _newMetricCtrl.text.trim();
                  if (k.isEmpty) return;
                  setState(() {
                    _knownMetricKeys.add(k);     // fica disponível globalmente
                    _toggleMetric(k, true);      // e já seleciona
                    _newMetricCtrl.clear();
                  });
                },
              ),
            ),
            onSubmitted: (_) {
              final k = _newMetricCtrl.text.trim();
              if (k.isEmpty) return;
              setState(() {
                _knownMetricKeys.add(k);
                _toggleMetric(k, true);
                _newMetricCtrl.clear();
              });
            },
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _primaryCtrl,
            decoration: const InputDecoration(labelText: 'Músculos primários (vírgulas)'),
            onChanged: (_) => _syncRawJsonFromForm(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _secondaryCtrl,
            decoration: const InputDecoration(labelText: 'Músculos secundários (vírgulas)'),
            onChanged: (_) => _syncRawJsonFromForm(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _metCtrl,
            decoration: const InputDecoration(labelText: 'MET (intensidade)'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _syncRawJsonFromForm(),
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showJson = !_showJson),
              icon: const Icon(Icons.code),
              label: Text(_showJson ? 'Ocultar JSON' : 'Ver/Editar JSON'),
            ),
          ),
          if (_showJson)
            SizedBox(
              height: 170,
              child: Column(children: [
                Expanded(
                  child: TextField(
                    controller: _rawJsonCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'JSON do exercício'),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      try {
                        final m = Map<String, dynamic>.from(jsonDecode(_rawJsonCtrl.text));
                        _fillFormFromJson(m);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON inválido: $e')));
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Preencher pelo JSON'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(onPressed: _syncRawJsonFromForm, icon: const Icon(Icons.refresh), label: const Text('Sincronizar do formulário')),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Excluir exercício?'),
            content: const Text('Esta ação não pode ser desfeita.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
            ],
          ),
        ) ?? false;
  }
}

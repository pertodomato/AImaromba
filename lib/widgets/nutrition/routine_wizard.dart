import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'nutrition_wizard_parts.dart' show ChatBubble; // subarquivo util abaixo
import '../../services/ai/nutrition_coach_service.dart';

/// Abre o wizard em tela cheia.
Future<void> showRoutineWizard(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _RoutineWizardSheet(),
  );
}

class _RoutineWizardSheet extends StatefulWidget {
  const _RoutineWizardSheet();

  @override
  State<_RoutineWizardSheet> createState() => _RoutineWizardSheetState();
}

class _RoutineWizardSheetState extends State<_RoutineWizardSheet> {
  final _c = TextEditingController();
  final List<Map<String, String>> _history = []; // {"role","text"}
  final _scroll = ScrollController();

  bool _loading = false;
  int _edits = 0;
  bool _forceFinalize = false;

  Map<String, dynamic>? _pendingSummary; // quando stage='summary'
  Map<String, dynamic>? _finalRoutine;   // quando stage='final'

  @override
  void initState() {
    super.initState();
    // Mensagem inicial do assistente
    _history.add({
      "role": "assistant",
      "text": "Oi! Vamos criar sua rotina de nutrição. Me conte seu objetivo (ex.: perder 4 kg em 8 semanas), "
              "seu dia a dia (horários possíveis para refeição), restrições e preferências."
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _history.add({"role": "user", "text": text.trim()});
      _loading = true;
      _pendingSummary = null;
      _finalRoutine = null;
    });

    final res = await NutritionCoach.step(
      history: _history,
      userNow: text.trim(),
      editsDone: _edits,
      forceFinalize: _forceFinalize,
    );

    setState(() {
      _loading = false;
      _history.add({"role": "assistant", "text": (res["text"] ?? "").toString()});
      if (res["stage"] == "summary") {
        _pendingSummary = {
          "summary": (res["summary"] ?? "").toString(),
        };
      } else if (res["stage"] == "final") {
        _finalRoutine = Map<String, dynamic>.from(res["routine"] ?? {});
      }
    });

    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finalizeNow() async {
    setState(() => _loading = true);
    final res = await NutritionCoach.finalize(history: _history);
    setState(() {
      _loading = false;
      _history.add({"role": "assistant", "text": (res["text"] ?? "").toString()});
      _finalRoutine = Map<String, dynamic>.from(res["routine"] ?? {});
    });
  }

  Future<void> _saveRoutine(Map<String, dynamic> r) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final box = Hive.box('nutrition_routines');
    // normaliza campos básicos
    final saveObj = {
      "id": "rt_$now",
      "name": (r["name"] ?? "Rotina de Nutrição").toString(),
      "summary": (r["summary"] ?? _pendingSummary?["summary"] ?? "").toString(),
      "notes": (r["notes"] ?? "").toString(),
      "buildingBlocks": r["buildingBlocks"] ?? const [],
      "days": r["days"] ?? const [],
      "createdAt": now,
    };
    await box.add(saveObj);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rotina salva!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente de Rotina (IA)')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in _history)
                  Align(
                    alignment: m["role"] == "user" ? Alignment.centerRight : Alignment.centerLeft,
                    child: ChatBubble(text: m["text"] ?? '', mine: m["role"] == "user"),
                  ),
                if (_pendingSummary != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumo proposto', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(_pendingSummary!["summary"] ?? ''),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () async {
                                  // Criar agora
                                  await _finalizeNow();
                                },
                                child: const Text('Criar rotina'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  // Ajustar (conta ciclos, até 3)
                                  setState(() {
                                    _edits++;
                                    if (_edits >= 3) _forceFinalize = true;
                                    _pendingSummary = null;
                                    _history.add({
                                      "role": "assistant",
                                      "text": _edits >= 3
                                          ? "Ok, chegamos ao limite de ajustes. Vou finalizar a rotina com base no que conversamos."
                                          : "Perfeito! O que você quer mudar ou detalhar?"
                                    });
                                  });
                                },
                                child: const Text('Quero ajustar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                ],
                if (_finalRoutine != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rotina pronta', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text((_finalRoutine!["summary"] ?? '').toString()),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => _saveRoutine(_finalRoutine!),
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Salvar rotina'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_loading) const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _send(v),
                    decoration: const InputDecoration(
                      hintText: 'Escreva aqui…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _send(_c.text),
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

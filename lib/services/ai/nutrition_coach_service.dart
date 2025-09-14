import 'dart:convert';
import 'package:hive/hive.dart';
import 'ai_core_service.dart';

/// Conversa para criar/ajustar rotina de nutrição.
/// - Usa as 3 últimas rotinas salvas como contexto.
/// - Até 3 ciclos de ajustes. Quando forceFinalize=true ou o usuário aceitar,
///   geramos a rotina detalhada.
/// Saídas SEMPRE em JSON (com fallback para texto se a IA não obedecer).
class NutritionCoach {
  /// Mensagens trocadas no chat local (UI).
  /// Cada item: {"role":"user|assistant","text":"..."}.
  static String _buildSystem(List<String> last3Summaries) {
    final prev = jsonEncode(last3Summaries);
    return '''
Você é um coach de nutrição que conversa em PT-BR e **SEMPRE** responde em JSON estrito.

CONTRATO DE RESPOSTA (apenas um objeto JSON):
{
  "stage": "ask" | "summary" | "final",
  "text": "mensagem para o usuário (markdown simples)",
  "summary": "resumo curto da rotina proposta (se stage='summary' ou 'final')",
  "routine": { ... rotina detalhada ... (apenas se stage='final') }
}

Fluxo:
1) Comece pedindo uma descrição do objetivo e hábitos do usuário.
2) Faça perguntas **pertinentes** (alimentos preferidos, restrições, horários, número de refeições/dia, meta de peso, disponibilidade).
3) Quando você achar que tem dados suficientes, devolva **stage='summary'** com um resumo claro.
4) Se o usuário pedir ajustes (no máx. 3 ciclos), refine o plano e volte ao summary.
5) Ao final (aceite explícito ou limite de 3 ajustes), gere **stage='final'** com a rotina detalhada e repetível.

Rotina detalhada (schema recomendado):
{
  "name": "string",
  "notes": "string",
  "summary": "string",
  "buildingBlocks": [
    {"name":"Café da manhã padrão","items":[{"time":"07:30","mealName":"Ovos e frutas","grams":300}]}
  ],
  "days": [
    {"dow":0,"items":[{"time":"07:30","mealName":"...","grams":...},{"time":"12:00","mealName":"..."}]},
    {"dow":1,"items":[ ... ]},
    ...
  ]
}

Contexto (3 últimas rotinas do usuário):
$prev

Regras:
- Responda **apenas** o JSON do contrato, sem texto fora do objeto.
- Se o usuário não souber de algo, proponha padrões plausíveis.
- Quantidades em gramas, horários HH:MM, português do Brasil.
''';
  }

  /// Junta o histórico local em um texto único para o modelo (porque usamos /chat/completions simples).
  static String _historyToUserPayload({
    required List<Map<String, String>> history,
    required String userNow,
    required int editsDone,
    required bool forceFinalize,
  }) {
    final h = history.map((m) => '[${m["role"]}] ${m["text"]}').join('\n');
    return '''
HISTÓRICO:
$h

INSTRUÇÕES DE CONTROLE:
- edits_done: $editsDone (máx 3)
- force_finalize: ${forceFinalize ? "true" : "false"}

NOVA MENSAGEM DO USUÁRIO:
$userNow

Responda no CONTRATO DE RESPOSTA.
''';
  }

  /// Passo da conversa: devolve {"stage","text","summary",?routine}
  static Future<Map<String, dynamic>> step({
    required List<Map<String, String>> history,
    required String userNow,
    required int editsDone,
    required bool forceFinalize,
  }) async {
    // Coleta últimos 3 summaries salvos
    final rBox = Hive.box('nutrition_routines');
    final items = rBox.values.whereType<Map>().toList();
    items.sort((a, b) => ((b['createdAt'] ?? 0) as int).compareTo((a['createdAt'] ?? 0) as int));
    final last3 = items.take(3).map((m) => (m['summary'] ?? (m['name'] ?? '')).toString()).toList();

    final system = _buildSystem(last3);
    final user = _historyToUserPayload(
      history: history,
      userNow: userNow,
      editsDone: editsDone,
      forceFinalize: forceFinalize,
    );

    final content = await AICore.chatOnceWithFallback(system: system, user: user);

    // Tenta parsear JSON do contrato:
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic> && obj['stage'] is String) return obj;
    } catch (_) {}
    // Fallback: IA respondeu texto puro
    return {
      "stage": "ask",
      "text": content.toString(),
    };
  }

  /// Pede explicitamente a versão FINAL usando todo o histórico.
  static Future<Map<String, dynamic>> finalize({
    required List<Map<String, String>> history,
  }) async {
    final system = _buildSystem(const []);
    final h = history.map((m) => '[${m["role"]}] ${m["text"]}').join('\n');
    final user = '''
Finalize a rotina detalhada agora (stage='final'). Use o histórico:
$h
''';
    final content = await AICore.chatOnceWithFallback(system: system, user: user);
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic> && obj['stage'] == 'final') return obj;
    } catch (_) {}
    // fallback: embrulha texto
    return {"stage": "final", "text": content.toString()};
  }
}

// lib/services/ai_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// Serviço de IA (3 camadas):
/// 1) chatOnce/...WithFallback → fala com a API (entra system/user, sai string)
/// 2) builders de prompt (exercício e sessão)
/// 3) alto nível: generateExerciseFromText / generateWorkoutDraftFromText / generatePlan
class AIService {
  // ===== Config =====
  static const String endpoint = 'https://api.openai.com/v1/chat/completions';

  // Ordem de tentativas (do +capaz para fallback)
  static const String modelPrimary   = 'gpt-5';
  static const String modelFallback1 = 'gpt-5-mini';
  static const String modelFallback2 = 'gpt-4o-mini';

  /// Chave padrão (pode ser substituída na tela Perfil)
  static const String defaultKey =
      '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';

  static const _storage = FlutterSecureStorage();
  static bool enableDebugLogs = true; // ligue/desligue logs

  // ===== Utils =====
  static Future<String> _effectiveKey() async {
    final k = (await _storage.read(key: 'openai_api_key'))?.trim();
    return (k == null || k.isEmpty) ? defaultKey : k;
  }

  static bool _isGpt5Family(String m) => m.startsWith('gpt-5');

  static String _trim(String s, [int max = 1600]) =>
      s.length <= max ? s : '${s.substring(0, max)}... <truncated>';

  // ============================================================
  // CAMADA 1 — CHAMADA CRUA (entra prompt → sai content string)
  // ============================================================
  /// Chamada mínima ao /chat/completions.
  /// NÃO envia temperature/max_tokens/reasoning para evitar erros no GPT-5.
  static Future<String> chatOnce({
    required String model,
    required String system,
    required String user,
    bool forceJsonWhenSafe = true,
  }) async {
    final key = await _effectiveKey();

    // Monta mensagens
    final messages = [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ];

    // Corpo mínimo. Para gpt-5: apenas model + messages.
    // Para modelos não-gpt-5, podemos sugerir JSON via response_format (quando suportado).
    final Map<String, dynamic> bodyMap = {
      'model': model,
      'messages': messages,
    };

    if (forceJsonWhenSafe && !_isGpt5Family(model)) {
      // Nem todo workspace aceita; se der 400 o fallback cuida.
      bodyMap['response_format'] = {'type': 'json_object'};
    }

    final body = jsonEncode(bodyMap);

    if (enableDebugLogs) {
      debugPrint('🛰️ AI.chatOnce → POST $endpoint');
      debugPrint('🧠 model=$model | forceJson=${forceJsonWhenSafe && !_isGpt5Family(model)}');
      debugPrint('📤 payload: ${_trim(body)}');
    }

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $key', // nunca logar a key
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (enableDebugLogs) {
      debugPrint('📥 status: ${resp.statusCode}');
      debugPrint('📥 body: ${_trim(resp.body)}');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (data['choices']?[0]?['message']?['content'] ?? '').toString();

    if (content.isEmpty) {
      throw Exception('Resposta vazia do modelo.');
    }
    return content;
  }

  /// Tenta em ordem: gpt-5 → gpt-5-mini → gpt-4o-mini
  static Future<String> chatOnceWithFallback({
    required String system,
    required String user,
  }) async {
    // 1) gpt-5
    try {
      return await chatOnce(model: modelPrimary, system: system, user: user);
    } catch (e) {
      if (enableDebugLogs) debugPrint('! Primário ($modelPrimary) falhou: $e');
    }

    // 2) gpt-5-mini
    try {
      return await chatOnce(model: modelFallback1, system: system, user: user);
    } catch (e) {
      if (enableDebugLogs) debugPrint('! Fallback1 ($modelFallback1) falhou: $e');
    }

    // 3) gpt-4o-mini (com JSON enforcado quando possível)
    return await chatOnce(
      model: modelFallback2,
      system: system,
      user: user,
      forceJsonWhenSafe: true,
    );
  }

  // ============================================================
  // CAMADA 2 — PROMPT BUILDERS
  // ============================================================

  /// Coleta métricas já usadas no DB (chave → exercícios que usam)
  static Map<String, List<String>> _collectKnownMetrics() {
    final out = <String, Set<String>>{};
    final exBox = Hive.box('exercises');
    for (final v in exBox.values) {
      if (v is Map && v['metrics'] is Map) {
        final m = Map<String, dynamic>.from(v['metrics']);
        final exName = (v['name'] ?? v['id'] ?? '').toString();
        m.forEach((k, val) {
          if (val == true) out.putIfAbsent(k, () => <String>{}).add(exName);
        });
      }
    }
    return out.map((k, s) => MapEntry(k, s.toList()..sort()));
  }

  /// Snapshot de exercícios disponíveis (id, name, metrics[], type)
  static List<Map<String, dynamic>> _availableExercisesSnapshot() {
    final exBox = Hive.box('exercises');
    final res = <Map<String, dynamic>>[];
    for (final v in exBox.values) {
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        final metrics = (m['metrics'] is Map)
            ? Map<String, dynamic>.from(m['metrics'])
                .entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .toList()
            : <String>[];
        res.add({
          'id': m['id'],
          'name': m['name'],
          'metrics': metrics,
          'type': m['type'],
        });
      }
    }
    res.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return res;
  }

  // -------- Exercício
  static String buildExerciseSystemPrompt(Map<String, List<String>> knownMetrics) {
    final metricsJson = jsonEncode(knownMetrics);
    return '''
Você é um gerador **ESTRITO** de JSON para exercícios. Responda **APENAS 1 objeto JSON** válido.

SCHEMA BASE (pode estender "metrics" com novas chaves quando fizer sentido):
{
  "id": "string_snake_case",
  "name": "string",
  "type": "strength|cardio|isometric|stretch",
  "metrics": { "<metric_key>": true|false, ... },
  "primary": ["string"],
  "secondary": ["string"],
  "met": number
}

REGRAS:
1) Somente JSON (nada fora do objeto).
2) "id" em snake_case (derivado de "name" se faltar).
3) Reutilize métricas conhecidas; pode criar novas (ex.: incline, pace, workSec, rpm, cadence, gradient, rounds...).
4) "type" ∈ {strength, cardio, isometric, stretch}. "met" plausível.
5) "primary"/"secondary" são grupos musculares (ou "cardio").

MÉTRICAS JÁ USADAS NO APP (chave → exemplos):
$metricsJson
''';
  }

  static String buildExerciseUserPrompt(String description) => '''
Converta a descrição do usuário em um ÚNICO objeto JSON seguindo o SCHEMA BASE.
Descrição do usuário:
"$description"
''';

  // -------- Sessão (workout) com padrões 5–6 exercícios e tempo por item
  static String buildWorkoutSystemPrompt({
    required List<Map<String, dynamic>> availableExercises,
  }) {
    final catalog = jsonEncode(availableExercises);
    return '''
Você gera **SESSÕES de treino** (não rotinas). Responda **APENAS JSON válido**.

PRIORIDADE
- **Priorize SEMPRE a descrição do usuário** (músculos, objetivo, duração, equipamentos).
- Se o usuário pedir algo específico, **siga a instrução**.
- Se o usuário NÃO especificar, aplique os padrões abaixo.

PADRÕES (quando não definidos pelo usuário):
- Duração total estimada: **30–90 min** (default 45–60).
- **Quantidade de exercícios**: **5–6**.
- **Séries por exercício**: **4**.
- **Descanso entre séries**: **90s**.
- Evite exercícios fora do foco (ex.: "peito/ombro/bíceps" ⇒ não sugerir agachamento/terra).

PROGRESSÃO / MÉTRICAS
- Cada item deve ter uma **métrica de progressão** coerente: weight|reps|timeSec|distanceKm|speedKmh|gradientPercent|custom.
- Use os exercícios existentes sempre que possível (EXERCICIOS_DISPONIVEIS).
- Se faltar, use "maybe_create" (o app criará os ids e reaplicará).

TEMPO POR EXERCÍCIO
- Inclua "estimatedItemMinutes" (trabalho + descansos) por exercício.
- A soma deve ficar **próxima** de "workout.estimatedDurationMin" (±10 min).

SCHEMA
{
  "maybe_create": {
    "needed": true|false,
    "items": [{"name":"string","description":"string"}]
  },
  "workout": {
    "id":"string_snake_case",
    "name":"string",
    "estimatedDurationMin": number,
    "items":[
      {
        "exerciseId":"string (opcional)",
        "exerciseName":"string (opcional)",
        "sets": number,
        "reps": "int|intervalo ex. 8-10",
        "restSec": number,
        "timeSec": number,
        "distanceKm": number,
        "speedKmh": number,
        "gradientPercent": number,
        "estimatedItemMinutes": number,
        "progression": {
          "metric":"weight|reps|timeSec|distanceKm|speedKmh|gradientPercent|custom",
          "strategy":"linear|double_progression|rpe|interval",
          "step": number,
          "minReps": number,
          "maxReps": number,
          "notes": "string"
        }
      }
    ]
  }
}

EXERCICIOS_DISPONIVEIS
$catalog

Responda **somente** o JSON no SCHEMA acima.
''';
  }

  static String buildWorkoutUserPrompt(String instruction) => '''
Gere UMA sessão a partir de:
"$instruction"

Se o usuário não definiu duração, quantidade de exercícios, séries ou descanso, aplique os padrões do system.
Inclua "estimatedItemMinutes" por exercício e mantenha a soma próxima de "estimatedDurationMin".
''';

  // ============================================================
  // CAMADA 3 — ALTO NÍVEL
  // ============================================================

  /// Gera JSON de exercício a partir de texto.
  static Future<Map<String, dynamic>?> generateExerciseFromText(String description) async {
    final desc = description.trim();
    if (desc.isEmpty) return null;

    final known = _collectKnownMetrics();
    final system = buildExerciseSystemPrompt(known);
    final user = buildExerciseUserPrompt(desc);

    try {
      final content = await chatOnceWithFallback(system: system, user: user);
      final obj = Map<String, dynamic>.from(jsonDecode(content));

      // Normalizações mínimas
      final t = (obj['type'] ?? 'strength').toString().toLowerCase();
      obj['type'] = (t == 'cardio' || t == 'isometric' || t == 'stretch') ? t : 'strength';

      final metrics = (obj['metrics'] is Map) ? Map<String, dynamic>.from(obj['metrics']) : <String, dynamic>{};
      final normalized = <String, bool>{};
      metrics.forEach((k, v) => normalized[k] = (v == true));
      obj['metrics'] = normalized;

      obj['primary']   = (obj['primary']   is List) ? List<String>.from(obj['primary'])   : <String>[];
      obj['secondary'] = (obj['secondary'] is List) ? List<String>.from(obj['secondary']) : <String>[];
      obj['met'] = (obj['met'] is num) ? (obj['met'] as num).toDouble() : 6.0;

      final name = (obj['name'] ?? 'exercicio').toString();
      obj['id'] = (obj['id'] ?? name)
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      if (enableDebugLogs) {
        debugPrint('✅ Exercício normalizado: ${_trim(jsonEncode(obj))}');
      }
      return obj;
    } catch (e) {
      if (enableDebugLogs) debugPrint('❌ generateExerciseFromText: $e');
      return null;
    }
  }

  /// Gera **draft** de sessão a partir de texto:
  /// - Pode pedir criação de exercícios (maybe_create) → cria e substitui por ids.
  /// - Retorna {'block': {...}} (não salva em boxes; a UI decide salvar/editar).
  static Future<Map<String, dynamic>?> generateWorkoutDraftFromText(String instruction) async {
    final available = _availableExercisesSnapshot();
    final system = buildWorkoutSystemPrompt(availableExercises: available);
    final user = buildWorkoutUserPrompt(instruction);

    Map<String, dynamic> response;
    try {
      final content = await chatOnceWithFallback(system: system, user: user);
      response = Map<String, dynamic>.from(jsonDecode(content));
    } catch (e) {
      if (enableDebugLogs) debugPrint('❌ parse workout JSON: $e');
      return null;
    }

    // 1) Criar exercícios faltantes
    final maybe = Map<String, dynamic>.from(response['maybe_create'] ?? {});
    final needed = maybe['needed'] == true;
    final createdMap = <String, String>{}; // name(lower) -> id
    if (needed) {
      final items = (maybe['items'] is List) ? List.from(maybe['items']) : const [];
      for (final it in items) {
        final name = (it['name'] ?? '').toString();
        final desc = (it['description'] ?? name).toString();
        if (name.isEmpty) continue;
        final ex = await generateExerciseFromText('$name — $desc');
        if (ex != null) {
          Hive.box('exercises').put(ex['id'], ex);
          createdMap[name.toLowerCase()] = ex['id'];
        }
      }
    }

    // 2) Normaliza workout → block draft
    final workout = Map<String, dynamic>.from(response['workout'] ?? {});
    if (workout.isEmpty) return null;

    final blockId = (workout['id'] ?? 'wb_${DateTime.now().millisecondsSinceEpoch}').toString();
    final items = <Map<String, dynamic>>[];
    final exBox = Hive.box('exercises');

    for (final raw in (workout['items'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(raw);
      String? exId = (m['exerciseId'] as String?);
      final exName = (m['exerciseName'] as String?)?.toLowerCase();

      if (exId == null || exId.isEmpty) {
        if (exName != null && exName.isNotEmpty) {
          if (createdMap.containsKey(exName)) {
            exId = createdMap[exName];
          } else {
            for (final v in exBox.values) {
              if (v is Map && (v['name'] as String?)?.toLowerCase() == exName) {
                exId = v['id'];
                break;
              }
            }
          }
        }
      }
      if (exId == null || !exBox.containsKey(exId)) continue;

      final out = <String, dynamic>{
        'exerciseId': exId,
        if (m['sets'] != null) 'sets': (m['sets'] as num).toInt(),
        if (m['reps'] != null) 'reps': m['reps'],
        if (m['restSec'] != null) 'restSec': (m['restSec'] as num).toInt(),
        if (m['timeSec'] != null) 'timeSec': (m['timeSec'] as num).toInt(),
        if (m['distanceKm'] != null) 'distanceKm': (m['distanceKm'] as num).toDouble(),
        if (m['speedKmh'] != null) 'speedKmh': (m['speedKmh'] as num).toDouble(),
        if (m['gradientPercent'] != null) 'gradientPercent': (m['gradientPercent'] as num).toDouble(),
        if (m['estimatedItemMinutes'] != null) 'estimatedItemMinutes': (m['estimatedItemMinutes'] as num).toDouble(),
        if (m['progression'] != null) 'progression': Map<String, dynamic>.from(m['progression']),
      };
      items.add(out);
    }
    if (items.isEmpty) return null;

    final block = {
      'id': blockId,
      'name': (workout['name'] ?? 'Sessão').toString(),
      'estimatedDurationMin': ((workout['estimatedDurationMin'] ?? 60) as num).toDouble().clamp(15, 180),
      'exercises': items,
    };

    if (enableDebugLogs) debugPrint('🧩 Draft de sessão: ${_trim(jsonEncode(block))}');
    return {'block': block};
  }

  /// Plano/routine (mantido para compatibilidade com telas antigas).
  /// Salva diretamente em 'blocks' e 'routine'. JSON deve vir correto do modelo.
  static Future<String?> generatePlan({
    required int days,
    required String goal,
    required int sessionMinutes,
    required List<String> equipment,
  }) async {
    final system = 'Responda apenas JSON válido (sem comentários).';
    final user =
        'Gere um plano EM JSON com schema {"blocks":[{"id":"string","name":"string","exercises":[{"exerciseId":"string","sets":int,"reps":int,"restSec":int}]}],"routine":{"id":"string","name":"string","calendar":{"YYYY-MM-DD":"blockId|descanso"}}}. '
        'Parâmetros: days=$days, goal="$goal", sessionMinutes=$sessionMinutes, equipment=${jsonEncode(equipment)}.';

    try {
      final content = await chatOnceWithFallback(system: system, user: user);
      final result = Map<String, dynamic>.from(jsonDecode(content));

      final blocks = Hive.box('blocks');
      for (final blk in (result['blocks'] as List? ?? const [])) {
        blocks.put(blk['id'], blk);
      }
      final r = result['routine'];
      if (r is Map) {
        Hive.box('routine').put(r['id'], r);
        Hive.box('profile').put('activeRoutine', r['id']);
      }
      if (enableDebugLogs) {
        debugPrint('✅ Plano salvo: ${_trim(jsonEncode(r))}');
      }
      return null;
    } catch (e) {
      if (enableDebugLogs) debugPrint('❌ generatePlan: $e');
      return 'Falha ao gerar/interpretar plano: $e';
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'ai_core_service.dart';

/// Prompts e alto nível para **exercícios**.
class ExercisePromptService {
  // ===== Helpers de DB/normalização =====
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

  static String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static Map<String, dynamic> _normalizeExercise(Map<String, dynamic> obj) {
    final t = (obj['type'] ?? 'strength').toString().toLowerCase();
    obj['type'] =
        (t == 'cardio' || t == 'isometric' || t == 'stretch') ? t : 'strength';

    final metrics = (obj['metrics'] is Map)
        ? Map<String, dynamic>.from(obj['metrics'])
        : <String, dynamic>{};
    final normalized = <String, bool>{};
    metrics.forEach((k, v) => normalized[k] = (v == true));
    obj['metrics'] = normalized;

    obj['primary'] =
        (obj['primary'] is List) ? List<String>.from(obj['primary']) : <String>[];
    obj['secondary'] = (obj['secondary'] is List)
        ? List<String>.from(obj['secondary'])
        : <String>[];
    obj['met'] = (obj['met'] is num) ? (obj['met'] as num).toDouble() : 6.0;

    final name = (obj['name'] ?? 'exercicio').toString();
    obj['id'] = _slugify((obj['id'] ?? name).toString());
    return obj;
  }

  // ===== Prompt builders =====
  static String _buildSystem(Map<String, List<String>> knownMetrics) {
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
6) Use português para os nomes e músculos, use o nome geral dos músculos, ex: peito, costas, tríceps e etc.
MÉTRICAS JÁ USADAS NO APP (chave → exemplos):
$metricsJson
''';
  }

  static String _buildUser(String description) => '''
Converta a descrição do usuário em um ÚNICO objeto JSON seguindo o SCHEMA BASE.
Descrição do usuário:
"$description"
''';

  // ===== Alto nível =====
  /// Gera JSON de exercício a partir de texto (não salva; retorna Map).
  static Future<Map<String, dynamic>?> generateExerciseFromText(
      String description) async {
    final desc = description.trim();
    if (desc.isEmpty) return null;

    final known = _collectKnownMetrics();
    final system = _buildSystem(known);
    final user = _buildUser(desc);

    try {
      final content =
          await AICore.chatOnceWithFallback(system: system, user: user);
      final obj = Map<String, dynamic>.from(jsonDecode(content));
      final normalized = _normalizeExercise(obj);
      if (AICore.enableDebugLogs) {
        debugPrint('✅ Exercício normalizado: '
            '${AICore.trimForLog(jsonEncode(normalized))}');
      }
      return normalized;
    } catch (e) {
      if (AICore.enableDebugLogs) {
        debugPrint('❌ generateExerciseFromText: $e');
      }
      return null;
    }
  }
}

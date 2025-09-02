import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'ai_core_service.dart';
import 'exercise_prompt_service.dart';

/// Prompts e alto nível para **sessões de treino** (workouts, não rotinas).
class SessionPromptService {
  // ===== Helpers DB =====
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

  // ===== Prompt builders =====
  static String _buildSystem({required List<Map<String, dynamic>> catalog}) {
    final catalogJson = jsonEncode(catalog);
    return '''
Você gera **SESSÕES de treino** (não rotinas). Responda **APENAS JSON válido**.

PRIORIDADE
- **Priorize SEMPRE a descrição do usuário** (músculos, objetivo, duração, equipamentos).
- Se NÃO especificar, aplique os padrões abaixo.

PADRÕES APROXIMADOS, nao precisa seguir a risca, se o usuário der motivos explícitos, implicitos ou se seu pedido demandar um número maior de exercicios por exemplo, pode quebrar esses padrões:
- Duração total estimada: **30–90 min** (default 45–60).
- **Quantidade de exercícios**: **5–6**.
- **Séries por exercício**: **4**.
- **Descanso entre séries**: **90s**.
- Evite exercícios fora do foco (ex.: pedido "peito/ombro/bíceps" ⇒ não sugerir agachamento/terra).

PROGRESSÃO / MÉTRICAS
- Cada item deve ter **métrica de progressão** coerente: weight|reps|timeSec|distanceKm|speedKmh|gradientPercent|custom.
- Use exercícios existentes (EXERCICIOS_DISPONIVEIS). Se faltar, use "maybe_create" (o app criará e reaplicará ids).

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
$catalogJson

Responda **somente** o JSON no SCHEMA acima.
''';
  }

  static String _buildUser(String instruction) => '''
Gere UMA sessão a partir de:
"$instruction"

Se o usuário não definiu duração, quantidade de exercícios, séries ou descanso, aplique os padrões do system.
Inclua "estimatedItemMinutes" por exercício e mantenha a soma próxima de "estimatedDurationMin".
''';

  // ===== Alto nível =====
  /// Gera um **draft** de sessão; cria exercícios faltantes (maybe_create) e substitui por ids.
  /// Retorna {'block': {...}} pronto para UI editar/salvar.
  static Future<Map<String, dynamic>?> generateWorkoutDraftFromText(
      String instruction) async {
    final catalog = _availableExercisesSnapshot();
    final system = _buildSystem(catalog: catalog);
    final user = _buildUser(instruction);

    Map<String, dynamic> response;
    try {
      final content =
          await AICore.chatOnceWithFallback(system: system, user: user);
      response = Map<String, dynamic>.from(jsonDecode(content));
    } catch (e) {
      if (AICore.enableDebugLogs) debugPrint('❌ parse workout JSON: $e');
      return null;
    }

    // 1) Criar exercícios faltantes se houver
    final maybe = Map<String, dynamic>.from(response['maybe_create'] ?? {});
    final needed = maybe['needed'] == true;
    final createdMap = <String, String>{}; // name(lower) -> id
    if (needed) {
      final items = (maybe['items'] is List) ? List.from(maybe['items']) : const [];
      for (final it in items) {
        final name = (it['name'] ?? '').toString();
        final desc = (it['description'] ?? name).toString();
        if (name.isEmpty) continue;
        final ex = await ExercisePromptService.generateExerciseFromText('$name — $desc');
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
      'estimatedDurationMin':
          ((workout['estimatedDurationMin'] ?? 60) as num).toDouble().clamp(15, 180),
      'exercises': items,
    };

    if (AICore.enableDebugLogs) {
      debugPrint('🧩 Draft de sessão: ${AICore.trimForLog(jsonEncode(block))}');
    }
    return {'block': block};
  }

  // (Opcional) Plano/routine — mantém compat p/ telas antigas se você quiser mover pra cá.
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
      final content = await AICore.chatOnceWithFallback(system: system, user: user);
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
      if (AICore.enableDebugLogs) {
        debugPrint('✅ Plano salvo: ${AICore.trimForLog(jsonEncode(r))}');
      }
      return null;
    } catch (e) {
      if (AICore.enableDebugLogs) debugPrint('❌ generatePlan: $e');
      return 'Falha ao gerar/interpretar plano: $e';
    }
  }
}

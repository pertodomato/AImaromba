import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Camada baixa de IA: fala com a API, gerencia fallback e logs.
/// Não conhece schema/prompt dos domínios.
class AICore {
  // Endpoint
  static const String endpoint = 'https://api.openai.com/v1/chat/completions';

  // Ordem de modelos: primário → fallbacks
  static const String modelPrimary   = 'gpt-5';
  static const String modelFallback1 = 'gpt-5-mini';
  static const String modelFallback2 = 'gpt-4o-mini';

  /// Chave padrão (o Perfil pode sobrescrever). Use apenas para dev.
  static const String defaultKey =
      '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';

  static const _storage = FlutterSecureStorage();
  static bool enableDebugLogs = true;

  static Future<String> _effectiveKey() async {
    final k = (await _storage.read(key: 'openai_api_key'))?.trim();
    return (k == null || k.isEmpty) ? defaultKey : k;
  }

  static bool _isGpt5Family(String m) => m.startsWith('gpt-5');

  static String trimForLog(String s, [int max = 1600]) =>
      s.length <= max ? s : '${s.substring(0, max)}... <truncated>';

  static String _trim(String s, [int max = 1600]) => trimForLog(s, max);

  // ============================================================
  // CHAMADA CRUA (texto→texto)
  // ============================================================
  static Future<String> chatOnce({
    required String model,
    required String system,
    required String user,
    bool forceJsonWhenSafe = true, // adiciona response_format só para não-gpt5
  }) async {
    final key = await _effectiveKey();

    final messages = [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ];

    final Map<String, dynamic> bodyMap = {
      'model': model,
      'messages': messages,
    };

    // Força JSON apenas em modelos que aceitam; gpt-5 quebra com params extras
    if (forceJsonWhenSafe && !_isGpt5Family(model)) {
      bodyMap['response_format'] = {'type': 'json_object'};
    }

    if (enableDebugLogs) {
      debugPrint('🛰️ AI.chatOnce → POST $endpoint');
      debugPrint('🧠 model=$model | forceJson=${forceJsonWhenSafe && !_isGpt5Family(model)}');
      debugPrint('📤 payload: ${_trim(jsonEncode(bodyMap))}');
    }

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bodyMap),
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

  /// Fallback: gpt-5 → gpt-5-mini → gpt-4o-mini
  static Future<String> chatOnceWithFallback({
    required String system,
    required String user,
  }) async {
    try {
      return await chatOnce(model: modelPrimary, system: system, user: user);
    } catch (e) {
      if (enableDebugLogs) debugPrint('! Primário ($modelPrimary) falhou: $e');
    }

    try {
      return await chatOnce(model: modelFallback1, system: system, user: user);
    } catch (e) {
      if (enableDebugLogs) debugPrint('! Fallback1 ($modelFallback1) falhou: $e');
    }

    return await chatOnce(
      model: modelFallback2,
      system: system,
      user: user,
      forceJsonWhenSafe: true,
    );
  }
}

/// Extensão para VISÃO (imagem → JSON estrito)
extension AICoreVision on AICore {
  static const String visionModel = 'gpt-4o-mini'; // suporta imagem + JSON

  /// `dataUrlImage`: "data:image/jpeg;base64,...."
  static Future<String> chatVisionOnce({
    required String system,
    required String userText,
    required String dataUrlImage,
  }) async {
    final key = await AICore._effectiveKey();

    final bodyMap = {
      'model': visionModel,
      'messages': [
        {'role': 'system', 'content': system},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
            {'type': 'image_url', 'image_url': {'url': dataUrlImage}}
          ]
        }
      ],
      'response_format': {'type': 'json_object'},
    };

    if (AICore.enableDebugLogs) {
      debugPrint('🛰️ AI.chatVisionOnce → POST ${AICore.endpoint}');
      debugPrint('🧠 model=$visionModel');
    }

    final resp = await http.post(
      Uri.parse(AICore.endpoint),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bodyMap),
    );

    if (AICore.enableDebugLogs) {
      debugPrint('📥 status: ${resp.statusCode}');
      debugPrint('📥 body: ${AICore.trimForLog(resp.body)}');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (data['choices']?[0]?['message']?['content'] ?? '').toString();
    if (content.isEmpty) throw Exception('Resposta vazia (visão).');
    return content;
  }

  static Future<String> chatVisionOnceWithFallback({
    required String system,
    required String userText,
    required String dataUrlImage,
  }) async {
    // Mantemos simples: reusa o mesmo modelo (o importante é funcionar)
    return await chatVisionOnce(system: system, userText: userText, dataUrlImage: dataUrlImage);
  }
}

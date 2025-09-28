// lib/core/services/llm_service.dart
// Abstração de LLM com saída JSON e suporte a texto+imagem.
// Ajuste: sem timeouts explícitos; fallback automático para gpt-5-mini.

import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart' as gg;
import 'package:dio/dio.dart';
import 'package:fitapp/core/models/user_profile.dart';

/// Contrato simples e estável
abstract class LLMProvider {
  /// Deve retornar SEMPRE uma string JSON.
  Future<String> getJson(String prompt, {List<Uint8List>? images});
}

/// Gemini (inalterado, removidos .timeout)
class GeminiProvider implements LLMProvider {
  final String apiKey;
  final String textModel;
  final String visionModel;

  late final gg.GenerativeModel _text;
  late final gg.GenerativeModel _vision;

  GeminiProvider(this.apiKey, {String? textModel, String? visionModel})
      : textModel = (textModel?.trim().isNotEmpty ?? false) ? textModel! : 'gemini-1.5-pro',
        visionModel = (visionModel?.trim().isNotEmpty ?? false) ? visionModel! : 'gemini-1.5-flash' {
    _text = gg.GenerativeModel(model: this.textModel, apiKey: apiKey);
    _vision = gg.GenerativeModel(model: this.visionModel, apiKey: apiKey);
  }

  @override
  Future<String> getJson(String prompt, {List<Uint8List>? images}) async {
    try {
      final sys = gg.Content.system('Você responde APENAS JSON. Sem comentários.');
      if (images != null && images.isNotEmpty) {
        final parts = <gg.Part>[gg.TextPart(prompt)];
        for (final bytes in images) {
          parts.add(gg.DataPart('image/jpeg', bytes));
        }
        final resp = await _vision.generateContent([sys, gg.Content.multi(parts)]);
        return resp.text ?? '{}';
      } else {
        final resp = await _text.generateContent([sys, gg.Content.text(prompt)]);
        return resp.text ?? '{}';
      }
    } catch (e) {
      return '{"error":"Gemini error","detail":"$e"}';
    }
  }
}

/// GPTProvider usando a API /v1/chat/completions
class GPTProvider implements LLMProvider {
  final String apiKey;
  final String model; // alvo preferido
  final Dio _dio = Dio();

  GPTProvider(this.apiKey, {String? model})
      : model = (model?.trim().isNotEmpty ?? false) ? model! : 'gpt-5-mini-high';

  @override
  Future<String> getJson(String prompt, {List<Uint8List>? images}) async {
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    final userContent = <Map<String, dynamic>>[
      {"type": "text", "text": prompt},
      if (images != null && images.isNotEmpty)
        for (final bytes in images)
          {
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,${base64Encode(bytes)}"}
          }
    ];

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": "Você responde APENAS JSON. Sem texto fora do JSON."},
      {"role": "user", "content": userContent},
    ];

    Future<Response<dynamic>> _call(String useModel) {
      final payload = {
        "model": useModel,
        "messages": messages,
        "response_format": {"type": "json_object"}
      };
      return _dio.post(
        endpoint,
        data: payload,
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
      );
    }

    String? _extractErrCode(dynamic data) {
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        final code = err['code'];
        return code?.toString();
      }
      return null;
    }

    String _extractErrMsg(dynamic data, String? fallback) {
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        final msg = err['message'];
        if (msg != null) return msg.toString();
      }
      return fallback ?? '';
    }

    try {
      final resp = await _call(model);
      if (resp.statusCode == 200 && resp.data != null) {
        return resp.data['choices'][0]['message']['content'] ?? '{}';
      }
      return jsonEncode(resp.data);
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        final msg = _extractErrMsg(data, e.message);
        final code = _extractErrCode(data);
        final isModelNotFound = (code == 'model_not_found') ||
            msg.contains('does not exist') ||
            msg.contains('not exist') ||
            msg.contains('do not have access') ||
            msg.contains('not found');

        if (isModelNotFound && model != 'gpt-5-mini') {
          try {
            final resp = await _call('gpt-5-mini');
            if (resp.statusCode == 200 && resp.data != null) {
              return resp.data['choices'][0]['message']['content'] ?? '{}';
            }
            return jsonEncode(resp.data);
          } catch (e2) {
            if (e2 is DioException) {
              return '{"error":"OpenAI API error","detail":"${e2.response?.data ?? e2.message}"}';
            }
            return '{"error":"OpenAI request failed","detail":"$e2"}';
          }
        }

        return '{"error":"OpenAI API error","detail":"${e.response?.data ?? e.message}"}';
      }
      return '{"error":"OpenAI request failed","detail":"$e"}';
    }
  }
}

/// Fachada
class LLMService {
  LLMProvider? _provider;

  void initialize(UserProfile profile) {
    if (profile.selectedLlm == 'gemini' && profile.geminiApiKey.isNotEmpty) {
      _provider = GeminiProvider(profile.geminiApiKey);
    } else if (profile.selectedLlm == 'gpt' && profile.gptApiKey.isNotEmpty) {
      // Usa default 'gpt-5-mini-high' com fallback interno para 'gpt-5-mini'
      _provider = GPTProvider(profile.gptApiKey);
    } else {
      _provider = null;
    }
  }

  bool isAvailable() => _provider != null;

  // Sem timeout externo; deixa o provedor decidir.
  Future<bool> ping() async {
    if (_provider == null) return false;
    try {
      final res = await _provider!.getJson('{"ping":true}');
      return res.isNotEmpty && !res.contains('"error"');
    } catch (_) {
      return false;
    }
  }

  Future<String> generateResponse(String prompt, {List<String>? imagesBase64}) {
    if (_provider == null) {
      throw Exception('LLM Provider não inicializado. Configure no Perfil.');
    }
    final imgs = imagesBase64?.map((s) => base64Decode(s)).toList();
    return _provider!.getJson(prompt, images: imgs);
  }

  Future<String> getJson(String prompt, {List<Uint8List>? images}) {
    if (_provider == null) {
      throw Exception('LLM Provider não inicializado. Configure no Perfil.');
    }
    return _provider!.getJson(prompt, images: images);
    }
}

// lib/core/services/llm_service.dart
// Abstração de LLM com saída JSON e suporte a texto+imagem.

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

/// Gemini (sem alterações, continua funcional)
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
        final resp = await _vision.generateContent([sys, gg.Content.multi(parts)]).timeout(const Duration(seconds: 45));
        return resp.text ?? '{}';
      } else {
        final resp = await _text.generateContent([sys, gg.Content.text(prompt)]).timeout(const Duration(seconds: 45));
        return resp.text ?? '{}';
      }
    } catch (e) {
      return '{"error":"Gemini error","detail":"$e"}';
    }
  }
}

/// GPTProvider usando a API /v1/chat/completions para maior compatibilidade
class GPTProvider implements LLMProvider {
  final String apiKey;
  final String model;
  final Dio _dio = Dio();

  GPTProvider(this.apiKey, {String? model})
      // MUDANÇA: Usando 'gpt-4o' como padrão, pois é mais estável e disponível.
      : model = (model?.trim().isNotEmpty ?? false) ? model! : 'gpt-4o';

  @override
  Future<String> getJson(String prompt, {List<Uint8List>? images}) async {
    // MUDANÇA: Voltamos ao endpoint padrão /v1/chat/completions que é mais comum.
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    final List<Map<String, dynamic>> messages = [
      {
        "role": "system",
        "content": "Você responde APENAS JSON. Sem texto fora do JSON."
      },
    ];

    // Monta a mensagem do usuário (pode ser multimodal)
    final List<Map<String, dynamic>> userContent = [];
    userContent.add({"type": "text", "text": prompt}); // Adiciona o prompt de texto

    if (images != null && images.isNotEmpty) {
      for (final bytes in images) {
        userContent.add({
          "type": "image_url",
          "image_url": {"url": "data:image/jpeg;base64,${base64Encode(bytes)}"}
        });
      }
    }

    messages.add({"role": "user", "content": userContent});

    final payload = {
      "model": model,
      "messages": messages,
      "max_tokens": 2048,
       // Para forçar o modo JSON em modelos que o suportam
      "response_format": {"type": "json_object"}
    };

    try {
      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 && response.data != null) {
        return response.data['choices'][0]['message']['content'] ?? '{}';
      }
      return jsonEncode(response.data);

    } catch (e) {
      if (e is DioException) {
        return '{"error":"OpenAI API error","detail":"${e.response?.data ?? e.message}"}';
      }
      return '{"error":"OpenAI request failed","detail":"$e"}';
    }
  }
}


/// Fachada (sem alterações)
class LLMService {
  LLMProvider? _provider;

  void initialize(UserProfile profile) {
    if (profile.selectedLlm == 'gemini' && profile.geminiApiKey.isNotEmpty) {
      _provider = GeminiProvider(profile.geminiApiKey);
    } else if (profile.selectedLlm == 'gpt' && profile.gptApiKey.isNotEmpty) {
      _provider = GPTProvider(profile.gptApiKey);
    } else {
      _provider = null;
    }
  }

  bool isAvailable() => _provider != null;

  Future<bool> ping({Duration timeout = const Duration(seconds: 15)}) async {
    if (_provider == null) return false;
    try {
      final res = await _provider!.getJson('{"ping":true}').timeout(timeout);
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
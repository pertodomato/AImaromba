// REPLACE WHOLE FILE
import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart' as gg;
import 'package:dart_openai/dart_openai.dart' as oa;
import 'package:seu_app/core/models/user_profile.dart';

/// Contrato simples e estável
abstract class LLMProvider {
  /// Sempre retorna string JSON. Se o provedor não suportar enforced JSON,
  /// o chamador deve sanitizar com json_safety.
  Future<String> getJson(String prompt, {List<Uint8List>? images});
}

/// Gemini 2.5 texto e visão
class GeminiProvider implements LLMProvider {
  final String apiKey;
  final String textModel;
  final String visionModel;

  late final gg.GenerativeModel _text;
  late final gg.GenerativeModel _vision;

  GeminiProvider(this.apiKey, {String? textModel, String? visionModel})
      : textModel = (textModel?.trim().isNotEmpty ?? false) ? textModel! : 'gemini-2.5-pro',
        visionModel = (visionModel?.trim().isNotEmpty ?? false) ? visionModel! : 'gemini-2.5-flash' {
    _text = gg.GenerativeModel(model: this.textModel, apiKey: apiKey);
    _vision = gg.GenerativeModel(model: this.visionModel, apiKey: apiKey);
  }

  @override
  Future<String> getJson(String prompt, {List<Uint8List>? images}) async {
    try {
      final sys = gg.Content.system('Você responde APENAS JSON. Sem comentários.'); // soft-constraint
      if (images != null && images.isNotEmpty) {
        final parts = <gg.Part>[gg.TextPart(prompt)];
        for (final bytes in images) {
          parts.add(gg.DataPart('image/jpeg', bytes));
        }
        final resp = await _vision.generateContent([sys, gg.Content.multi(parts)]).timeout(const Duration(seconds: 30));
        return resp.text ?? '{}';
      } else {
        final resp = await _text.generateContent([sys, gg.Content.text(prompt)]).timeout(const Duration(seconds: 30));
        return resp.text ?? '{}';
      }
    } catch (e) {
      return '{"error":"Gemini error","detail":"$e"}';
    }
  }
}

/// GPT-5 Thinking ou fallback gpt-4o
class GPTProvider implements LLMProvider {
  final String apiKey;
  final String model;

  GPTProvider(this.apiKey, {String? model})
      : model = (model?.trim().isNotEmpty ?? false) ? model! : 'gpt-5-thinking' {
    oa.OpenAI.apiKey = apiKey;
  }

  @override
  Future<String> getJson(String prompt, {List<Uint8List>? images}) async {
    try {
      final msgs = <oa.OpenAIChatCompletionChoiceMessageModel>[
        oa.OpenAIChatCompletionChoiceMessageModel(
          role: oa.OpenAIChatMessageRole.system,
          content: [oa.OpenAIChatCompletionChoiceMessageContentItemModel.text('Você responde APENAS JSON. Sem texto fora do JSON.')],
        ),
        if (images != null && images.isNotEmpty)
          oa.OpenAIChatCompletionChoiceMessageModel(
            role: oa.OpenAIChatMessageRole.user,
            content: [
              oa.OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
              for (final b in images)
                oa.OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl('data:image/jpeg;base64,${base64Encode(b)}'),
            ],
          )
        else
          oa.OpenAIChatCompletionChoiceMessageModel(
            role: oa.OpenAIChatMessageRole.user,
            content: [oa.OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
          ),
      ];

      final resp = await oa.OpenAI.instance.chat.create(
        model: model,
        responseFormat: {"type": "json_object"},
        messages: msgs,
      ).timeout(const Duration(seconds: 30));

      return resp.choices.first.message.content?.first.text ?? '{}';
    } catch (e) {
      return '{"error":"OpenAI error","detail":"$e"}';
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
      _provider = GPTProvider(profile.gptApiKey);
    } else {
      _provider = null;
    }
  }

  bool isAvailable() => _provider != null;

  Future<bool> ping({Duration timeout = const Duration(seconds: 6)}) async {
    if (_provider == null) return false;
    try {
      final res = await _provider!.getJson('{"ping":true}').timeout(timeout);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Retorna string JSON (talvez suja). Use json_safety no chamador quando precisar de Map.
  Future<String> getJson(String prompt, {List<Uint8List>? images}) {
    if (_provider == null) {
      throw Exception('LLM Provider não inicializado. Configure no Perfil.');
    }
    return _provider!.getJson(prompt, images: images);
  }
}

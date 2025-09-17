import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:seu_app/core/models/user_profile.dart';

/// Interface
abstract class LLMProvider {
  Future<String> getResponse(String prompt, {List<String>? imageBase64});
}

/// Gemini
class GeminiProvider implements LLMProvider {
  final String apiKey;
  final String textModel;
  final String visionModel;

  late final GenerativeModel _text;
  late final GenerativeModel _vision;

  GeminiProvider(this.apiKey, {String? textModel, String? visionModel})
      : textModel = textModel?.trim().isNotEmpty == true ? textModel! : 'gemini-2.5-pro',
        visionModel = visionModel?.trim().isNotEmpty == true ? visionModel! : 'gemini-1.5-pro-vision' {
    _text = GenerativeModel(model: this.textModel, apiKey: apiKey);
    _vision = GenerativeModel(model: this.visionModel, apiKey: apiKey);
  }

  @override
  Future<String> getResponse(String prompt, {List<String>? imageBase64}) async {
    try {
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final parts = <DataPart>[];
        for (final b64 in imageBase64) {
          final bytes = base64Decode(b64);
          parts.add(DataPart('image/jpeg', bytes));
        }
        final resp = await _vision.generateContent([Content.multi([...parts, TextPart(prompt)])]);
        return resp.text ?? 'Erro: resposta vazia do modelo de visão.';
      } else {
        final resp = await _text.generateContent([Content.text(prompt)]);
        return resp.text ?? 'Erro: resposta vazia do modelo.';
      }
    } catch (e) {
      return 'Erro Gemini: $e';
    }
  }
}

/// GPT
class GPTProvider implements LLMProvider {
  final String apiKey;
  final String model;

  GPTProvider(this.apiKey, {String? model})
      : model = model?.trim().isNotEmpty == true ? model! : 'gpt-4o' {
    OpenAI.apiKey = apiKey;
  }

  @override
  Future<String> getResponse(String prompt, {List<String>? imageBase64}) async {
    try {
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final content = <OpenAIChatCompletionChoiceMessageContentItemModel>[
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          for (final b64 in imageBase64)
            OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl('data:image/jpeg;base64,$b64'),
        ];
        final response = await OpenAI.instance.chat.create(
          model: model,
          messages: [
            OpenAIChatCompletionChoiceMessageModel(role: OpenAIChatMessageRole.user, content: content),
          ],
        );
        return response.choices.first.message.content?.first.text ?? 'Erro: resposta vazia (visão).';
      } else {
        final response = await OpenAI.instance.chat.create(
          model: model,
          responseFormat: {"type": "json_object"},
          messages: [
            OpenAIChatCompletionChoiceMessageModel(
              role: OpenAIChatMessageRole.system,
              content: [OpenAIChatCompletionChoiceMessageContentItemModel.text('Você responde apenas JSON.')],
            ),
            OpenAIChatCompletionChoiceMessageModel(
              role: OpenAIChatMessageRole.user,
              content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
            ),
          ],
        );
        return response.choices.first.message.content?.first.text ?? 'Erro: resposta vazia.';
      }
    } catch (e) {
      return 'Erro OpenAI: $e';
    }
  }
}

/// Serviço principal
class LLMService {
  LLMProvider? _provider;

  void initialize(UserProfile profile) {
    if (profile.selectedLlm == 'gemini' && profile.geminiApiKey.isNotEmpty) {
      _provider = GeminiProvider(
        profile.geminiApiKey,
        textModel: 'gemini-2.5-pro',
        visionModel: 'gemini-1.5-pro-vision',
      );
    } else if (profile.selectedLlm == 'gpt' && profile.gptApiKey.isNotEmpty) {
      _provider = GPTProvider(
        profile.gptApiKey,
        model: 'gpt-4o',
      );
    } else {
      _provider = null;
    }
  }

  bool isAvailable() => _provider != null;
  Future<bool> ping({Duration timeout = const Duration(seconds: 6)}) async {
    if (_provider == null) return false;
    try {
      final f = _provider!.getResponse('{"ping":true}');
      final res = await f.timeout(timeout);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  Future<String> generateResponse(String prompt, {List<String>? imagesBase64}) {
    if (_provider == null) {
      throw Exception('LLM Provider não inicializado. Configure no Perfil.');
    }
    return _provider!.getResponse(prompt, imageBase64: imagesBase64);
  }
}

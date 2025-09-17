import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:seu_app/core/models/user_profile.dart';

// Interface
abstract class LLMProvider {
  Future<String> getResponse(String prompt, {List<String>? imageBase64});
}

// Implementação para Gemini
class GeminiProvider implements LLMProvider {
  final String apiKey;
  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;

  GeminiProvider(this.apiKey) {
    _model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey); // Verifique o nome do modelo mais recente
    _visionModel = GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
  }

  @override
  Future<String> getResponse(String prompt, {List<String>? imageBase64}) async {
    try {
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final imageParts = imageBase64.map((img) => DataPart('image/jpeg', Uri.dataFromBytes(img.codeUnits).data!.contentAsBytes())).toList();
        final content = [Content.multi([...imageParts, TextPart(prompt)])];
        final response = await _visionModel.generateContent(content);
        return response.text ?? "Erro: Não obtive resposta do modelo de visão.";
      } else {
        final content = [Content.text(prompt)];
        final response = await _model.generateContent(content);
        return response.text ?? "Erro: Não obtive resposta do modelo.";
      }
    } catch (e) {
      print("Erro na API Gemini: $e");
      return "Erro ao contatar a API do Gemini. Verifique sua chave e conexão.";
    }
  }
}

// Implementação para GPT
class GPTProvider implements LLMProvider {
  final String apiKey;

  GPTProvider(this.apiKey) {
    OpenAI.apiKey = apiKey;
  }

  @override
  Future<String> getResponse(String prompt, {List<String>? imageBase64}) async {
    try {
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // GPT-5/4o Vision
        final imageMessages = imageBase64.map((img) => OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl("data:image/jpeg;base64,$img")).toList();
        final response = await OpenAI.instance.chat.create(
          model: "gpt-4o", // ou o modelo mais recente com visão
          messages: [
            OpenAIChatCompletionChoiceMessageModel(role: OpenAIChatMessageRole.user, content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
              ...imageMessages,
            ]),
          ],
        );
        return response.choices.first.message.content?.first.text ?? "Erro: Não obtive resposta do modelo de visão GPT.";
      } else {
        final response = await OpenAI.instance.chat.create(
          model: "gpt-4o", // ou o modelo de texto mais recente
          responseFormat: {"type": "json_object"}, // Forçar saída JSON
          messages: [
            OpenAIChatCompletionChoiceMessageModel(role: OpenAIChatMessageRole.system, content: [OpenAIChatCompletionChoiceMessageContentItemModel.text("You are a helpful assistant designed to output JSON.")]),
            OpenAIChatCompletionChoiceMessageModel(role: OpenAIChatMessageRole.user, content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)]),
          ],
        );
        return response.choices.first.message.content?.first.text ?? "Erro: Não obtive resposta do modelo GPT.";
      }
    } catch (e) {
      print("Erro na API OpenAI: $e");
      return "Erro ao contatar a API do OpenAI. Verifique sua chave e conexão.";
    }
  }
}

// Serviço principal que o app usará
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

  Future<String> generateResponse(String prompt, {List<String>? imagesBase64}) {
    if (_provider == null) {
      throw Exception("LLM Provider não inicializado. Verifique as chaves de API no perfil.");
    }
    return _provider!.getResponse(prompt, imageBase64: imagesBase64);
  }
}
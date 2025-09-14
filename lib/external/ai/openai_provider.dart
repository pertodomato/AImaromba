// lib/external/ai/openai_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/env/env.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/message.dart';
import 'ai_provider.dart';

class OpenAIProvider implements AiProvider {
  final String model;
  OpenAIProvider({this.model = 'gpt-4o-mini'});

  @override
  Future<String> getResponse(List<Message> conversation) async {
    final apiKey = await Env.getOpenAiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw AiFailure('Chave de API da OpenAI não configurada.');
    }

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final body = jsonEncode({
      'model': model,
      'messages': conversation.map((msg) => msg.toMap()).toList(),
      'response_format': {'type': 'json_object'}, // Forçar saída JSON
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        if (content.isEmpty) {
          throw AiFailure('A API retornou uma resposta vazia.');
        }
        return content;
      } else {
        throw AiFailure('Erro na API OpenAI: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw NetworkFailure('Falha de conexão ao chamar a API da OpenAI: $e');
    }
  }
}
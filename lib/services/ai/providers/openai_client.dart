import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../get_response.dart';

class OpenAIClient implements LLMClient {
  final String model; // ex: gpt-4o-mini, gpt-4.1
  final FlutterSecureStorage storage;
  final String apiKeyKey; // ex: 'openai_api_key'
  OpenAIClient({
    required this.model,
    required this.storage,
    this.apiKeyKey = 'openai_api_key',
  });

  @override
  Future<String> chat({required List<Map<String, String>> messages, Map<String, dynamic>? jsonSchema}) async {
    final key = (await storage.read(key: apiKeyKey))?.trim();
    if (key == null || key.isEmpty) { throw Exception('OpenAI API key ausente'); }

    final body = <String,dynamic>{
      'model': model,
      'messages': messages.map((m)=> {'role': m['role'], 'content': m['content']}).toList(),
    };

    if (jsonSchema != null) {
      body['response_format'] = {'type':'json_schema','json_schema': {'name':'response','schema': jsonSchema}};
    }

    final resp = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'Authorization':'Bearer $key','Content-Type':'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('OpenAI HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String,dynamic>;
    final content = (data['choices']?[0]?['message']?['content'] ?? '').toString();
    if (content.isEmpty) { throw Exception('Resposta vazia'); }
    return content;
  }
}

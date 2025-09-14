import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../get_response.dart';

class GeminiClient implements LLMClient {
  final String model; // ex: gemini-1.5-pro
  final FlutterSecureStorage storage;
  final String apiKeyKey; // ex: 'gemini_api_key'
  GeminiClient({required this.model, required this.storage, this.apiKeyKey = 'gemini_api_key'});

  @override
  Future<String> chat({required List<Map<String, String>> messages, Map<String, dynamic>? jsonSchema}) async {
    final key = (await storage.read(key: apiKeyKey))?.trim();
    if (key == null || key.isEmpty) { throw Exception('Gemini API key ausente'); }

    final parts = messages.map((m)=> {'role': m['role'], 'content': [{'text': m['content']}] }).toList();

    final body = <String,dynamic>{
      'contents': parts,
    };
    // Gemini “Structured output” pode exigir function calling; aqui exigimos JSON por instrução no system
    final resp = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String,dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    final text = candidates.isEmpty ? '' : (candidates[0]['content']?['parts']?[0]?['text'] ?? '').toString();
    if (text.isEmpty) { throw Exception('Resposta vazia'); }
    return text;
  }
}

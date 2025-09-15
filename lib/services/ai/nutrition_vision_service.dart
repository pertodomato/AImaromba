import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:fitapp/core/env/env.dart';
import 'package:fitapp/core/errors/failures.dart';

class NutritionVisionService {
  static const _model = 'gpt-4o-mini'; // visão
  static Future<Map<String, dynamic>> analyze(Uint8List imageBytes) async {
    final key = await Env.getOpenAiApiKey();
    if (key == null || key.isEmpty) {
      throw AiFailure('Chave OpenAI não configurada.');
    }
    final b64 = base64Encode(imageBytes);
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': _model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': 'Extraia macros aproximadas em JSON: { "kcal": number, "protein": number, "carbs": number, "fat": number, "description": string }'
        },
        {
          'role': 'user',
          'content': [
            {'type':'text','text':'Analise a refeição nesta imagem e retorne apenas o JSON solicitado.'},
            {'type':'image_url','image_url': {'url':'data:image/jpeg;base64,$b64'}}
          ]
        }
      ]
    };
    final resp = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw AiFailure('OpenAI erro ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final content = data['choices'][0]['message']['content'] as String? ?? '';
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw AiFailure('Resposta não-JSON: $content');
    }
  }
}

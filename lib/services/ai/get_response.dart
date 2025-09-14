import 'dart:convert';

abstract class LLMClient {
  Future<String> chat({
    required List<Map<String,String>> messages, // [{role:'system'|'user'|'assistant', content:'...'}]
    Map<String,dynamic>? jsonSchema, // se presente, exigir JSON
  });
}

class GetResponse {
  final LLMClient client;
  GetResponse(this.client);

  /// Retorna texto ou JSON (quando jsonSchema != null).
  Future<T> call<T>({
    required List<Map<String,String>> messages,
    Map<String,dynamic>? jsonSchema,
    T Function(String raw)? decode,
  }) async {
    final raw = await client.chat(messages: messages, jsonSchema: jsonSchema);
    if (jsonSchema == null) {
      return (decode != null ? decode(raw) : raw) as T;
    }
    final obj = jsonDecode(raw);
    return (decode != null ? decode(jsonEncode(obj)) : obj) as T;
  }
}

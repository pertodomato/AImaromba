import 'dart:convert';
import 'dart:typed_data';
import 'package:fitapp/services/ai/ai_core_service.dart';

/// Converte foto/texto em um objeto de refeição.
/// Retorna: {"description":string,"kcal":double,"protein":double,"carbs":double,"fat":double}
class NutritionVision {
  static String _system() => '''
Você é um extrator de nutrientes. Responda APENAS um objeto JSON:
{"description":"string","kcal":number,"protein":number,"carbs":number,"fat":number}
- kcal/protein/carbs/fat se referem à porção observada (não por 100g).
- Quando a entrada incluir imagem em base64 data URL, considere-a junto do texto.
''';

  static Future<Map<String, dynamic>> _parse(String user) async {
    final content = await AICore.chatOnceWithFallback(system: _system(), user: user);
    final obj = jsonDecode(content) as Map<String, dynamic>;
    return {
      "description": (obj["description"] ?? "").toString(),
      "kcal": (obj["kcal"] as num?)?.toDouble() ?? 0,
      "protein": (obj["protein"] as num?)?.toDouble() ?? 0,
      "carbs": (obj["carbs"] as num?)?.toDouble() ?? 0,
      "fat": (obj["fat"] as num?)?.toDouble() ?? 0,
    };
  }

  static Future<Map<String, dynamic>> mealFromPhoto(Uint8List bytes, {String hint = ''}) {
    final b64 = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$b64';
    final user = 'Imagem (data URL): $dataUrl\nHint: $hint';
    return _parse(user);
    // Observação: modelos com visão interpretam data URLs em /chat/completions.
  }

  static Future<Map<String, dynamic>> mealFromText(String description) {
    final user = 'Descrição: $description';
    return _parse(user);
  }
}

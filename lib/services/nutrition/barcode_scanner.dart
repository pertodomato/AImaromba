import 'dart:convert';
import 'package:http/http.dart' as http;

/// Consulta o OpenFoodFacts e devolve macros por 100g.
/// Retorno: {"name":string,"kcal":double,"protein":double,"carbs":double,"fat":double}
class BarcodeScanner {
  static Future<Map<String, dynamic>?> lookupBarcode(String ean) async {
    if (ean.isEmpty) return null;
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$ean.json');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if ((data['status'] as int? ?? 0) != 1) return null;
    final p = data['product'] as Map<String, dynamic>?;

    final nutr = (p?['nutriments'] as Map?)?.cast<String, dynamic>() ?? {};
    double _d(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

    return {
      "name": (p?['product_name'] ?? '').toString(),
      "kcal": _d(nutr['energy-kcal_100g']),
      "protein": _d(nutr['proteins_100g']),
      "carbs": _d(nutr['carbohydrates_100g']),
      "fat": _d(nutr['fat_100g']),
    };
  }
}

// lib/data/repositories/implementations/scan_repository_impl.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitapp/data/repositories/scan_repository.dart';
import 'package:fitapp/domain/entities/nutrition.dart';
import '../../../core/errors/failures.dart';

class ScanRepositoryImpl implements ScanRepository {
  @override
  Future<FoodProduct?> lookupByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode?fields=product_name,nutriments');
    
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final p = data['product'] as Map<String, dynamic>?;
      if (p == null) return null;

      final nutr = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? {};
      double d(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0.0);

      return FoodProduct(
        barcode: barcode,
        name: p['product_name']?.toString() ?? 'Produto não encontrado',
        kcalPer100g: d(nutr['energy-kcal_100g']),
        proteinPer100g: d(nutr['proteins_100g']),
        carbsPer100g: d(nutr['carbohydrates_100g']),
        fatPer100g: d(nutr['fat_100g']),
      );
    } catch (e) {
      throw NetworkFailure('Falha ao buscar código de barras: $e');
    }
  }
}
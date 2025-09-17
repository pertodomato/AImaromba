import 'dart:math';
import 'package:dio/dio.dart';
import 'package:seu_app/core/models/meal.dart';

class FoodApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<Meal?> fetchFoodByBarcode(String barcode) async {
    final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';

    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final response = await _dio.get(url, queryParameters: {'fields': 'product_name,nutriments'});
        if (response.statusCode == 200 && response.data['status'] == 1) {
          final product = response.data['product'];
          final nutriments = product['nutriments'];
          return Meal(
            id: barcode,
            name: product['product_name'] ?? 'Produto sem nome',
            description: 'Produto via código de barras $barcode',
            caloriesPer100g: (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
            proteinPer100g: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
            carbsPer100g: (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
            fatPer100g: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
          );
        }
        return null;
      } on DioException catch (_) {
        if (attempts >= 3) return null;
        final backoffMs = 300 * pow(2, attempts - 1);
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

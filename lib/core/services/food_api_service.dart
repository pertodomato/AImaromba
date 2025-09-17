import 'package:dio/dio.dart';
import 'package:seu_app/core/models/meal.dart';

class FoodApiService {
  final Dio _dio = Dio();

  Future<Meal?> fetchFoodByBarcode(String barcode) async {
    final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
    try {
      final response = await _dio.get(url, queryParameters: {
        'fields': 'product_name,nutriments'
      });

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
    } catch (e) {
      // log
      return null;
    }
  }
}

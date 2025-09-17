import 'package:dio/dio.dart';
import 'package:seu_app/core/models/meal.dart'; // Você precisará criar o modelo Meal.dart

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
        
        // Criando um objeto Meal a partir da resposta da API
        return Meal(
          id: barcode,
          name: product['product_name'] ?? 'Nome não encontrado',
          description: 'Produto escaneado via código de barras.',
          caloriesPer100g: (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
          proteinPer100g: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
          carbsPer100g: (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
          fatPer100g: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
        );
      }
      return null;
    } catch (e) {
      print("Erro ao buscar produto: $e");
      return null;
    }
  }
}
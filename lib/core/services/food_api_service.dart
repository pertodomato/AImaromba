// REPLACE WHOLE FILE
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:seu_app/core/models/meal.dart';

/// Consulta OpenFoodFacts e mantém cache curto em Hive ('_food_cache')
class FoodApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Retorna Meal por barcode. Tenta cache local antes.
  /// [retries] tentativas com backoff exponencial.
  Future<Meal?> fetchFoodByBarcode(String barcode, {int retries = 2}) async {
    final id = barcode.trim();
    if (id.isEmpty) return null;

    // cache
    final cache = await _openCache();
    final cached = cache.get(id) as Map?;
    if (cached != null) {
      return _mealFromCache(id, cached);
    }

    final url = 'https://world.openfoodfacts.org/api/v2/product/$id.json';
    int attempts = 0;

    while (attempts <= retries) {
      attempts++;
      try {
        final resp = await _dio.get(url, queryParameters: {'fields': 'product_name,nutriments'});
        if (resp.statusCode == 200 && resp.data['status'] == 1) {
          final product = resp.data['product'];
          final nutr = product['nutriments'] ?? {};
          final meal = Meal(
            id: id,
            name: (product['product_name'] ?? 'Produto sem nome').toString(),
            description: 'Produto via código de barras $id',
            caloriesPer100g: (nutr['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
            proteinPer100g: (nutr['proteins_100g'] as num?)?.toDouble() ?? 0.0,
            carbsPer100g: (nutr['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
            fatPer100g: (nutr['fat_100g'] as num?)?.toDouble() ?? 0.0,
          );
          await cache.put(id, {
            'n': meal.name,
            'c': meal.caloriesPer100g,
            'p': meal.proteinPer100g,
            'cb': meal.carbsPer100g,
            'f': meal.fatPer100g,
          });
          return meal;
        }
        return null;
      } on DioException {
        if (attempts > retries) return null;
        final backoffMs = 300 * pow(2, attempts - 1);
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Meal _mealFromCache(String id, Map data) {
    return Meal(
      id: id,
      name: (data['n'] ?? 'Produto').toString(),
      description: 'Produto via código de barras $id (cache)',
      caloriesPer100g: ((data['c'] ?? 0) as num).toDouble(),
      proteinPer100g: ((data['p'] ?? 0) as num).toDouble(),
      carbsPer100g: ((data['cb'] ?? 0) as num).toDouble(),
      fatPer100g: ((data['f'] ?? 0) as num).toDouble(),
    );
  }

  Future<Box> _openCache() async {
    const box = '_food_cache';
    if (!Hive.isBoxOpen(box)) {
      await Hive.openBox(box);
    }
    return Hive.box(box);
  }
}

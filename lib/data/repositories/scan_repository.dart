import 'package:fitapp/domain/entities/nutrition.dart';

abstract class ScanRepository {
  Future<FoodProduct?> lookupByBarcode(String barcode);
}

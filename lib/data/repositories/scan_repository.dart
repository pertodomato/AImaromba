// lib/data/repositories/scan_repository.dart

// Stubs de modelos
class Food {}

abstract interface class ScanRepository {
  Future<Food?> lookupByBarcode(String barcode);
}
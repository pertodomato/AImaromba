// lib/screens/nutrition/barcode_scan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/nutrition.dart';
import '../../presentation/providers/repository_providers.dart';


final scanResultProvider = StateProvider<FoodProduct?>((ref) => null);

class BarcodeScanScreen extends ConsumerWidget {
  const BarcodeScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(scanResultProvider);
    
    Future<void> saveProduct() async {
      if (product == null) return;
      
      final profile = await ref.read(profileRepositoryProvider).getActive();
      final input = FoodLogInput(
        profileId: profile.id,
        source: 'barcode',
        kcal: product.kcalPer100g, // Assumindo porção de 100g
        protein: product.proteinPer100g,
        carbs: product.carbsPer100g,
        fat: product.fatPer100g,
        notes: product.name,
        barcode: product.barcode,
      );

      try {
        await ref.read(nutritionRepositoryProvider).saveFoodLog(input);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} adicionado!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Código de Barras')),
      body: product == null
          ? MobileScanner(
              onDetect: (capture) async {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode != null) {
                  try {
                    final p = await ref.read(scanRepositoryProvider).lookupByBarcode(barcode);
                    ref.read(scanResultProvider.notifier).state = p;
                  } catch (e) {
                    // Handle error
                  }
                }
              },
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Por 100g:'),
                      Text('Kcal: ${product.kcalPer100g.toStringAsFixed(1)}'),
                      Text('Proteínas: ${product.proteinPer100g.toStringAsFixed(1)}g'),
                      Text('Carboidratos: ${product.carbsPer100g.toStringAsFixed(1)}g'),
                      Text('Gorduras: ${product.fatPer100g.toStringAsFixed(1)}g'),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => ref.read(scanResultProvider.notifier).state = null,
                            child: const Text('Escanear Outro'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: saveProduct,
                            child: const Text('Adicionar 100g'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
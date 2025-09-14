import 'package:flutter/material.dart';
import '../../services/nutrition/barcode_scanner.dart';
import '../../widgets/nutrition/add_meal_sheet.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});
  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final codeC = TextEditingController();
  Map<String, dynamic>? _product;
  String? _error;
  bool _loading = false;

  Future<void> _lookup() async {
    setState(() { _loading = true; _error = null; _product = null; });
    try {
      final p = await BarcodeScanner.lookupBarcode(codeC.text.trim());
      if (p == null) {
        setState(() => _error = 'Produto não encontrado.');
      } else {
        setState(() => _product = p);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código de barras')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: codeC, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'EAN/GTIN', hintText: 'Ex.: 7891000315505', border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _lookup, icon: const Icon(Icons.search), label: const Text('Buscar')),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_product != null) Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_product!['name'] ?? 'Produto'),
                const SizedBox(height: 4),
                Text('100g: ${_product!['kcal']} kcal • P:${_product!['protein']} C:${_product!['carbs']} G:${_product!['fat']}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => showAddMealSheet(context),
                  icon: const Icon(Icons.add), label: const Text('Adicionar às minhas refeições'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

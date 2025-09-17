import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});
  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final body = kIsWeb
        ? _WebFallback(onResult: _finishWith)
        : MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final raw = barcodes.first.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _finishWith(raw);
                }
              }
            },
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Código')),
      body: body,
    );
  }

  void _finishWith(String value) {
    if (_done) return;
    _done = true;
    Navigator.pop(context, value);
  }
}

class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.upload),
        label: const Text('Enviar imagem do código (web)'),
        onPressed: () async {
          final picker = ImagePicker();
          final x = await picker.pickImage(source: ImageSource.gallery);
          if (x == null) return;

          // Fallback: devolve "file://" apenas para retornar ao chamador,
          // que pode usar IA de OCR/Barcode se desejar.
          onResult('file://${x.name}');
        },
      ),
    );
  }
}

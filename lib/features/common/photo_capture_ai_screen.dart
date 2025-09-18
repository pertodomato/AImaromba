import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/meal.dart' as core;
import 'package:fitapp/core/models/meal_entry.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/meal_ai_service.dart';

class PhotoCaptureAIScreen extends StatefulWidget {
  const PhotoCaptureAIScreen({super.key});
  @override
  State<PhotoCaptureAIScreen> createState() => _PhotoCaptureAIScreenState();
}

class _PhotoCaptureAIScreenState extends State<PhotoCaptureAIScreen> {
  final _picker = ImagePicker();
  XFile? _file;
  bool _loading = false;

  Future<void> _capture() async {
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img == null) return;
    setState(() => _file = img);
  }

  Future<void> _runAI() async {
    if (_file == null) return;
    final llm = context.read<LLMService>();
    if (!llm.isAvailable()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure a IA no Perfil.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await File(_file!.path).readAsBytes();
      final b64 = base64Encode(bytes);
      final ai = MealAIService(llm);
      final meal = await ai.fromImage([b64], extraText: null);
      if (meal == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não retornou alimento.')));
        }
        return;
      }
      await _collectAndSave(meal);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _collectAndSave(core.Meal meal) async {
    final gramsCtl = TextEditingController();
    final labelCtl = TextEditingController(text: 'Refeição');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade - ${meal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: gramsCtl, decoration: const InputDecoration(labelText: 'Gramas (g)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: labelCtl, decoration: const InputDecoration(labelText: 'Rótulo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final grams = double.tryParse(gramsCtl.text.trim());
              if (grams == null || grams <= 0) {
                Navigator.pop(ctx);
                return;
              }
              final hive = context.read<HiveService>();
              await hive.getBox<core.Meal>('meals').add(meal);
              await hive.getBox<MealEntry>('meal_entries').add(MealEntry(
                    id: const Uuid().v4(),
                    dateTime: DateTime.now(),
                    label: labelCtl.text.trim().isEmpty ? 'Refeição' : labelCtl.text.trim(),
                    meal: meal,
                    grams: grams,
                  ));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _capture();
  }

  @override
  Widget build(BuildContext context) {
    final img = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('IA por Foto')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : (img == null
                ? const Text('Nenhuma foto. Toque em “Tirar Foto”.')
                : Image.file(File(img.path))),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _capture, child: const Text('Tirar Foto'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _runAI, child: const Text('Analisar com IA'))),
          ],
        ),
      ),
    );
  }
}

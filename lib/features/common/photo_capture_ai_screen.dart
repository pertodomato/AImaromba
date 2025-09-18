// lib/features/common/photo_capture_ai_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/meal.dart';
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
  bool _busy = false;
  File? _img;

  Future<void> _pick(ImageSource src) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 90);
    if (x == null) return;
    setState(() => _img = File(x.path));
    await _process();
  }

  Future<void> _process() async {
    final llm = context.read<LLMService>();
    if (!llm.isAvailable()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure a IA no Perfil.')));
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await _img!.readAsBytes();
      final b64 = base64Encode(bytes);

      final ai = MealAIService(llm);
      final result = await ai.fromImageAuto([b64], extraText: 'Estime nome do prato e peso total em gramas.');
      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não conseguiu entender a foto.')));
        return;
      }

      // Salva alimento, depois cria entrada com gramas estimadas.
      final hive = context.read<HiveService>();
      final mealsBox = hive.getBox<Meal>('meals');

      // Evita duplicar por nome + macros (heurística simples)
      Meal? toUse;
      try {
        toUse = mealsBox.values.firstWhere((m) =>
            m.name.toLowerCase() == result.meal.name.toLowerCase() &&
            m.caloriesPer100g == result.meal.caloriesPer100g &&
            m.proteinPer100g == result.meal.proteinPer100g &&
            m.carbsPer100g == result.meal.carbsPer100g &&
            m.fatPer100g == result.meal.fatPer100g);
      } catch (_) {
        toUse = null;
      }

      toUse ??= result.meal;
      if (toUse == result.meal) {
        await mealsBox.add(toUse);
      }

      await hive.getBox<MealEntry>('meal_entries').add(MealEntry(
            id: const Uuid().v4(),
            dateTime: DateTime.now(),
            label: 'Refeição',
            meal: toUse,
            grams: result.grmsClamp(),
          ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refeição registrada: ${toUse.name} • ${result.grmsClamp().toStringAsFixed(0)} g')),
      );
      Navigator.pop(context); // volta pra Home; ela recarrega o dashboard
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar com IA (foto)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _busy
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analisando a foto...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (img != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(img, height: 240, fit: BoxFit.cover),
                      )
                    else
                      const Icon(Icons.photo_size_select_actual, size: 96),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Câmera'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeria'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Pequena extensão para garantir faixa razoável de 80–1200 g
extension on ({Meal meal, double grams}) {
  double grmsClamp() => grams.clamp(80.0, 1200.0);
}

// lib/features/common/photo_capture_ai_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/meal_entry.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/meal_ai_service.dart';
import 'package:fitapp/features/5_nutrition/presentation/pages/meal_details_screen.dart';

class PhotoCaptureAIScreen extends StatefulWidget {
  const PhotoCaptureAIScreen({super.key});

  @override
  State<PhotoCaptureAIScreen> createState() => _PhotoCaptureAIScreenState();
}

class _PhotoCaptureAIScreenState extends State<PhotoCaptureAIScreen> {
  bool _busy = false;
  XFile? _pickedFile;

  Future<void> _pick(ImageSource src) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: src, imageQuality: 90, maxWidth: 1024);
    if (xfile == null) return;

    setState(() => _pickedFile = xfile);
    await _process(xfile);
  }

  Future<void> _process(XFile pickedFile) async {
    final llm = context.read<LLMService>();
    if (!llm.isAvailable()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure a IA no Perfil.')));
      return;
    }

    setState(() => _busy = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final b64 = base64Encode(bytes);

      final ai = MealAIService(llm);
      // MUDANÇA: Chamando o novo método que retorna a tupla
      final resultTuple = await ai.fromImageAutoWithRawResponse([b64], extraText: 'Estime nome do prato e peso total em gramas.');
      
      final result = resultTuple?.result;
      final rawAiResponse = resultTuple?.rawResponse ?? '{"error":"No response from AI"}';
      
      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não conseguiu entender a foto.')));
        return;
      }

      final hive = context.read<HiveService>();
      final mealsBox = hive.getBox<Meal>('meals');

      Meal? toUse;
      try {
        toUse = mealsBox.values.firstWhere((m) =>
            m.name.toLowerCase() == result.meal.name.toLowerCase() &&
            (m.caloriesPer100g - result.meal.caloriesPer100g).abs() < 1 &&
            (m.proteinPer100g - result.meal.proteinPer100g).abs() < 1);
      } catch (_) {
        toUse = null;
      }

      toUse ??= result.meal;

      // MUDANÇA: Adicionada verificação de nulidade para corrigir os erros
      if (toUse != null) {
        if (!toUse.isInBox) {
          await mealsBox.add(toUse);
        }

        final newMealEntry = MealEntry(
              id: const Uuid().v4(),
              dateTime: DateTime.now(),
              label: 'Refeição (IA Foto)',
              meal: toUse, // Agora 'toUse' é garantido como não-nulo aqui dentro
              grams: result.grmsClamp(),
            );
        await hive.getBox<MealEntry>('meal_entries').add(newMealEntry);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MealDetailsScreen(
              mealEntry: newMealEntry,
              imagePath: pickedFile.path,
              aiResponseJson: rawAiResponse,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickedFile = _pickedFile;
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
                    if (pickedFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(pickedFile.path, height: 240, fit: BoxFit.cover)
                            : Image.file(File(pickedFile.path), height: 240, fit: BoxFit.cover),
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

extension on ({Meal meal, double grams}) {
  double grmsClamp() => grams.clamp(80.0, 1200.0);
}
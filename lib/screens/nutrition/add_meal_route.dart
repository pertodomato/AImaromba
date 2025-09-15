import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/nutrition.dart';
import '../../presentation/providers/repository_providers.dart';
import '../../external/ai/get_response.dart';
import '../../services/ai/nutrition_vision_service.dart';

class AddMealRoute extends StatefulWidget {
  final String? initialTab; // 'photo' | 'text'
  const AddMealRoute({super.key, this.initialTab});
  @override
  State<AddMealRoute> createState() => _AddMealRouteState();
}

class _AddMealRouteState extends State<AddMealRoute> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'text' ? 1 : 0;
    _tab = TabController(length: 2, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Refeição'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.photo_camera), text: 'Foto (IA)'),
            Tab(icon: Icon(Icons.edit_note), text: 'Texto (IA)'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_PhotoTab(), _TextTab()],
      ),
    );
  }
}

// ----- base state -----
abstract class _MealTabState<T extends ConsumerStatefulWidget> extends ConsumerState<T> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _mealResult;

  void setLoading(bool v) => setState(() => _loading = v);
  void setError(String? v) => setState(() => _error = v);
  void setMealResult(Map<String, dynamic>? r) => setState(() => _mealResult = r);

  Future<void> _saveMeal(String source) async {
    if (_mealResult == null) return;

    // Se ainda não tiver ProfileRepository, troque por "final profileId = 1;"
    final profile = await ref.read(profileRepositoryProvider).getActive();
    final profileId = profile.id;

    final input = FoodLogInput(
      profileId: profileId,
      source: source,
      kcal: (_mealResult!['kcal'] as num?)?.toDouble() ?? 0,
      protein: (_mealResult!['protein'] as num?)?.toDouble() ?? 0,
      carbs: (_mealResult!['carbs'] as num?)?.toDouble() ?? 0,
      fat: (_mealResult!['fat'] as num?)?.toDouble() ?? 0,
      notes: _mealResult!['description']?.toString(),
      barcode: null,
    );

    try {
      await ref.read(nutritionRepositoryProvider).saveFoodLog(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refeição salva com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar refeição: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget buildResultCard(String source) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Erro: $_error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_mealResult == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Detectado: ${_mealResult!['description'] ?? 'N/A'}'),
          const SizedBox(height: 8),
          Text('kcal: ${_mealResult!['kcal']}  •  P: ${_mealResult!['protein']}  •  C: ${_mealResult!['carbs']}  •  G: ${_mealResult!['fat']}'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _saveMeal(source),
            icon: const Icon(Icons.save),
            label: const Text('Salvar Refeição'),
          )
        ]),
      ),
    );
  }
}

// ----- Foto (Visão) -----
class _PhotoTab extends ConsumerStatefulWidget {
  const _PhotoTab();
  @override
  ConsumerState<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends _MealTabState<_PhotoTab> {
  Future<void> _pickAndAnalyze(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 75, maxWidth: 1024);
    if (x == null) return;

    setLoading(true);
    setError(null);
    setMealResult(null);

    try {
      final Uint8List bytes = await x.readAsBytes();
      final result = await NutritionVisionService.analyze(bytes);
      setMealResult(result);
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          ElevatedButton.icon(
            onPressed: () => _pickAndAnalyze(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Câmera'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _pickAndAnalyze(ImageSource.gallery),
            icon: const Icon(Icons.image),
            label: const Text('Galeria'),
          ),
        ]),
        const SizedBox(height: 16),
        buildResultCard('photo_ia'),
      ],
    );
  }
}

// ----- Texto (LLM) -----
class _TextTab extends ConsumerStatefulWidget {
  const _TextTab();
  @override
  ConsumerState<_TextTab> createState() => _TextTabState();
}

class _TextTabState extends _MealTabState<_TextTab> {
  final _controller = TextEditingController();

  Future<void> _sendToIA() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setLoading(true);
    setError(null);
    setMealResult(null);

    try {
      final result = await ref.read(aiServiceProvider).getResponse(
        promptFile: 'nutrition.json',
        promptKey: 'meal_from_text',
        placeholders: {'user_description': text},
      );
      setMealResult(result);
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Descreva a refeição (ex.: 150g arroz, 120g frango grelhado, salada)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _sendToIA,
          icon: const Icon(Icons.psychology),
          label: const Text('Analisar com IA'),
        ),
        const SizedBox(height: 12),
        buildResultCard('text_ia'),
      ],
    );
  }
}

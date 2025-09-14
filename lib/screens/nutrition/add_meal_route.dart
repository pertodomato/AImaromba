// lib/screens/nutrition/add_meal_route.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/nutrition.dart';
import '../../external/ai/get_response.dart';
import '../../presentation/providers/repository_providers.dart';

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
  void dispose() { _tab.dispose(); super.dispose(); }

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
      body: TabBarView(controller: _tab, children: const [_PhotoTab(), _TextTab()]),
    );
  }
}

// Classe base para compartilhar a lógica de salvar
abstract class _MealTabState<T extends StatefulWidget> extends ConsumerState<T> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _mealResult;

  void setLoading(bool loading) => setState(() => _loading = loading);
  void setError(String? error) => setState(() => _error = error);
  void setMealResult(Map<String, dynamic>? result) => setState(() => _mealResult = result);

  Future<void> _saveMeal(String source) async {
    if (_mealResult == null) return;
    
    final profile = await ref.read(profileRepositoryProvider).getActive();
    final input = FoodLogInput(
      profileId: profile.id,
      source: source,
      kcal: (_mealResult!['kcal'] as num?)?.toDouble() ?? 0,
      protein: (_mealResult!['protein'] as num?)?.toDouble() ?? 0,
      carbs: (_mealResult!['carbs'] as num?)?.toDouble() ?? 0,
      fat: (_mealResult!['fat'] as num?)?.toDouble() ?? 0,
      notes: _mealResult!['description']?.toString(),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Text('Erro: $_error', style: const TextStyle(color: Colors.red));
    if (_mealResult != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detectado: ${_mealResult!['description'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('kcal:${_mealResult!['kcal']} P:${_mealResult!['protein']} C:${_mealResult!['carbs']} G:${_mealResult!['fat']}'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _saveMeal(source),
                icon: const Icon(Icons.save),
                label: const Text('Salvar Refeição'),
              )
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PhotoTab extends ConsumerStatefulWidget { const _PhotoTab(); @override ConsumerState<_PhotoTab> createState() => _PhotoTabState(); }
class _PhotoTabState extends _MealTabState<_PhotoTab> {
  
  Future<void> _pickAndAnalyze(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 75, maxWidth: 1024);
    if (x == null) return;

    setLoading(true);
    setError(null);
    setMealResult(null);

    try {
      final aiService = ref.read(aiServiceProvider);
      // Aqui, o ideal seria passar a imagem em base64, mas o getResponse atual não suporta
      // Vamos simular com o nome do arquivo por enquanto, a lógica real precisaria de um
      // método específico para visão na fachada.
      final result = await aiService.getResponse(
        promptFile: 'nutrition.json',
        promptKey: 'meal_from_text', // Usando texto como fallback
        placeholders: {'user_description': 'Uma foto de um prato de comida.'}, // Placeholder
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
        Row(
          children: [
            ElevatedButton.icon(onPressed: () => _pickAndAnalyze(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Câmera')),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () => _pickAndAnalyze(ImageSource.gallery), icon: const Icon(Icons.image), label: const Text('Galeria')),
          ],
        ),
        const SizedBox(height: 16),
        buildResultCard('photo_ia'),
      ],
    );
  }
}

class _TextTab extends ConsumerStatefulWidget { const _TextTab(); @override ConsumerState<_TextTab> createState() => _TextTabState(); }
class _TextTabState extends _MealTabState<_TextTab> {
  final _controller = TextEditingController();

  Future<void> _sendToIA() async {
    if (_controller.text.trim().isEmpty) return;
    
    setLoading(true);
    setError(null);
    setMealResult(null);

    try {
      final result = await ref.read(aiServiceProvider).getResponse(
        promptFile: 'nutrition.json',
        promptKey: 'meal_from_text',
        placeholders: {'user_description': _controller.text.trim()},
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
          controller: _controller, maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Descreva a refeição (ex.: 150g arroz, 120g frango grelhado, salada)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(onPressed: _sendToIA, icon: const Icon(Icons.psychology), label: const Text('Analisar com IA')),
        const SizedBox(height: 12),
        buildResultCard('text_ia'),
      ],
    );
  }
}
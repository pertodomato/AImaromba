import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai/nutrition_vision_service.dart';
import '../../widgets/nutrition/add_meal_sheet.dart';

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
        title: const Text('Adicionar refeição'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.photo_camera), text: 'Foto (IA)'),
            Tab(icon: Icon(Icons.edit_note), text: 'Texto'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [_PhotoTab(), _TextTab()]),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.list_alt),
        onPressed: () => context.go('/nutrition/history'),
      ),
    );
  }
}

class _PhotoTab extends StatefulWidget { const _PhotoTab(); @override State<_PhotoTab> createState() => _PhotoTabState(); }
class _PhotoTabState extends State<_PhotoTab> {
  Uint8List? _bytes;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _meal;

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 75);
    if (x == null) return;
    _bytes = await x.readAsBytes();
    setState(() { _loading = true; _error = null; _meal = null; });
    try {
      final result = await NutritionVision.mealFromPhoto(_bytes!, hint: '');
      setState(() => _meal = result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ElevatedButton.icon(onPressed: () => _pick(ImageSource.camera),  icon: const Icon(Icons.photo_camera), label: const Text('Câmera')),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.image), label: const Text('Galeria')),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_meal != null) Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Detectado: ${_meal!['description']}\n'
                'kcal:${_meal!['kcal']} P:${_meal!['protein']} C:${_meal!['carbs']} G:${_meal!['fat']}'),
          ),
        ),
      ],
    );
  }
}

class _TextTab extends StatefulWidget { const _TextTab(); @override State<_TextTab> createState() => _TextTabState(); }
class _TextTabState extends State<_TextTab> {
  final c = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _meal;
  String? _error;

  Future<void> _sendToIA() async {
    setState(() { _loading = true; _error = null; _meal = null; });
    try {
      final result = await NutritionVision.mealFromText(c.text.trim());
      setState(() => _meal = result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: c, maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Descreva a refeição (ex.: 150g arroz, 120g frango grelhado, salada)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(onPressed: _sendToIA, icon: const Icon(Icons.psychology), label: const Text('IA')),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () => showAddMealSheet(context), icon: const Icon(Icons.view_list), label: const Text('Opções')),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_meal != null) Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Sugerido: ${_meal!['description']}\n'
                'kcal:${_meal!['kcal']} P:${_meal!['protein']} C:${_meal!['carbs']} G:${_meal!['fat']}'),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/meal.dart';
import 'package:fitapp/core/models/meal_entry.dart';
import 'package:fitapp/core/services/food_api_service.dart';
import 'package:fitapp/core/services/food_repository.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/meal_ai_service.dart';
import 'package:fitapp/features/common/scan_barcode_screen.dart';
import 'package:fitapp/features/common/photo_capture_ai_screen.dart';
import 'package:fitapp/core/utils/diet_schedule_utils.dart';

class NutritionHubScreen extends StatefulWidget {
  const NutritionHubScreen({super.key});
  @override
  State<NutritionHubScreen> createState() => _NutritionHubScreenState();
}

class _NutritionHubScreenState extends State<NutritionHubScreen> {
  late List<MealEntry> _todays;
  double _kcal = 0;
  double _dailyGoalKcal = 0;
  String? _dietGoalLabel;
  String? _dietWeightGoal;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final hive = context.read<HiveService>();
    final entries = hive.getBox<MealEntry>('meal_entries').values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final now = DateTime.now();
    _todays = entries.where((e) =>
      e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day).toList();
    _kcal = _todays.fold(0.0, (s, e) => s + e.calories);

    final profile = hive.getUserProfile();
    _dailyGoalKcal = (profile.dailyKcalGoal ?? 2000).toDouble();
    _dietGoalLabel = null;
    _dietWeightGoal = null;

    final dietTarget = DietScheduleUtils.resolveDailyTarget(hive: hive);
    if (dietTarget != null) {
      if (dietTarget.hasCalorieGoal) {
        _dailyGoalKcal = dietTarget.calories;
      }
      final label = dietTarget.displayLabel;
      if (label != null) {
        _dietGoalLabel = label;
      }
      _dietWeightGoal = dietTarget.weightGoal;
    }
    setState(() {});
  }

  Future<void> _addByBarcode() async {
    final barcode = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const ScanBarcodeScreen()));
    if (barcode == null) return;
    final hive = context.read<HiveService>();
    final mealsBox = hive.getBox<Meal>('meals');

    Meal? meal;
    try {
      meal = mealsBox.values.firstWhere((m) => m.id == barcode);
    } catch (_) {
      meal = null;
    }

    meal ??= await FoodApiService().fetchFoodByBarcode(barcode);

    if (meal == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alimento não encontrado.')));
      return;
    }
    final mealToStore = meal!;
    final alreadyStored = mealsBox.values.any((m) => m.id == mealToStore.id);
    if (!alreadyStored) await mealsBox.add(mealToStore);

    await _collectAndSave(mealToStore);
  }

  Future<void> _addByTaco() async {
    final repo = context.read<FoodRepository>();
    final hive = context.read<HiveService>();
    final mealsBox = hive.getBox<Meal>('meals');

    final controller = TextEditingController();
    final labelCtl = TextEditingController(text: 'Refeição');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pesquisar alimento (TACO)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ex.: Peito de frango')),
            const SizedBox(height: 8),
            TextField(controller: labelCtl, decoration: const InputDecoration(labelText: 'Rótulo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final q = controller.text.trim();
              Navigator.pop(ctx);
              final res = repo.searchByName(q);
              if (res.isEmpty) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não encontrado no TACO.')));
                return;
              }
              final meal = res.first;
              if (!mealsBox.values.any((m) => m.id == meal.id)) await mealsBox.add(meal);
              await _collectAndSave(meal, presetLabel: labelCtl.text.trim());
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> _addByAIText() async {
    final descCtl = TextEditingController();
    final gramsCtl = TextEditingController();
    final labelCtl = TextEditingController(text: 'Refeição');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descrever refeição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descCtl, decoration: const InputDecoration(hintText: 'Ex.: Prato com frango, arroz e feijão')),
            const SizedBox(height: 8),
            TextField(controller: gramsCtl, decoration: const InputDecoration(labelText: 'Gramas (g)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: labelCtl, decoration: const InputDecoration(labelText: 'Rótulo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final desc = descCtl.text.trim();
              final grams = double.tryParse(gramsCtl.text.trim());
              Navigator.pop(ctx);
              final llm = context.read<LLMService>();
              if (desc.isEmpty || grams == null || grams <= 0 || !llm.isAvailable()) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados inválidos ou IA não configurada.')));
                return;
              }
              final hive = context.read<HiveService>();
              final dietTarget = DietScheduleUtils.resolveDailyTarget(hive: hive);
              final bias = DietScheduleUtils.calorieBiasForGoal(
                dietTarget?.weightGoal ?? _dietWeightGoal,
              );
              final meal = await MealAIService(llm).fromText(desc, calorieBias: bias);
              if (meal == null) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não retornou alimento.')));
                return;
              }
              await hive.getBox<Meal>('meals').add(meal);
              await hive.getBox<MealEntry>('meal_entries').add(MealEntry(
                id: const Uuid().v4(),
                dateTime: DateTime.now(),
                label: labelCtl.text.trim().isEmpty ? 'Refeição' : labelCtl.text.trim(),
                meal: meal,
                grams: grams,
              ));
              _reload();
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _collectAndSave(Meal meal, {String? presetLabel}) async {
    final gramsCtl = TextEditingController();
    final labelCtl = TextEditingController(text: presetLabel ?? 'Refeição');
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
              await hive.getBox<MealEntry>('meal_entries').add(MealEntry(
                id: const Uuid().v4(),
                dateTime: DateTime.now(),
                label: labelCtl.text.trim().isEmpty ? 'Refeição' : labelCtl.text.trim(),
                meal: meal,
                grams: grams,
              ));
              if (mounted) Navigator.pop(ctx);
              _reload();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Adicionar por Código de Barras'),
              onTap: () { Navigator.pop(ctx); _addByBarcode(); },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Adicionar por Texto (TACO)'),
              onTap: () { Navigator.pop(ctx); _addByTaco(); },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Adicionar com IA (texto)'),
              onTap: () { Navigator.pop(ctx); _addByAIText(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_front),
              title: const Text('Adicionar com IA (foto)'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoCaptureAIScreen()));
                _reload();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
    final goal = _dailyGoalKcal > 0 ? _dailyGoalKcal : null;
    final progress = goal != null && goal > 0 ? (_kcal / goal).clamp(0.0, 1.0) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrição')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department),
              title: Text('Consumido hoje: ${_kcal.toStringAsFixed(0)} kcal'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_todays.length} itens'),
                  if (goal != null) ...[
                    const SizedBox(height: 4),
                    Text('Meta do plano: ${goal.toStringAsFixed(0)} kcal'),
                    if (_dietGoalLabel != null)
                      Text(
                        _dietGoalLabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                  ],
                ],
              ),
              isThreeLine: goal != null,
            ),
          ),
          const SizedBox(height: 12),
          if (_todays.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem entradas hoje.')))
          else
            ..._todays.map((e) => Card(
              child: ListTile(
                title: Text('${e.label} — ${e.meal.name}'),
                subtitle: Text('${e.grams.toStringAsFixed(0)} g  ·  ${e.calories.toStringAsFixed(0)} kcal'),
                trailing: Text('${fmt.format(e.protein)}g P'),
              ),
            )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
        tooltip: 'Adicionar refeição',
      ),
    );
  }
}

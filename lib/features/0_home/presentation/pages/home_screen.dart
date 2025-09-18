import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fitapp/features/common/photo_capture_ai_screen.dart';
import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/food_api_service.dart';
import 'package:fitapp/core/services/food_repository.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/meal_ai_service.dart';

import 'package:fitapp/features/common/scan_barcode_screen.dart';
import 'package:fitapp/features/1_workout_tracker/presentation/pages/workout_in_progress_screen.dart';
import 'package:fitapp/features/5_nutrition/presentation/pages/meal_details_screen.dart'; // MUDANÇA: Importar a nova tela
import 'package:fitapp/features/7_settings/presentation/pages/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MealEntry? _nextMeal;
  WorkoutSession? _nextSession;
  String _nextSessionDayName = '';
  double _consumedKcal = 0;
  double _dailyGoalKcal = 2000;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ... (o resto do arquivo até a função _collectMealAmountAndSave permanece igual)
  
  void _loadDashboard() {
    final hive = context.read<HiveService>();

    // Próximo treino pela primeira rotina
    final routines = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    if (routines.isNotEmpty) {
      final r = routines.first;
      final days = r.days.toList();
      if (days.isNotEmpty) {
        final today = DateTime.now();
        final diff = today.difference(r.startDate).inDays;
        final idx = diff >= 0 && days.isNotEmpty ? diff % days.length : 0;
        final day = days[idx];
        _nextSessionDayName = day.name;
        final sessions = day.sessions.toList();
        if (sessions.isNotEmpty) _nextSession = sessions.first;
      }
    }

    // Próxima refeição de hoje e kcal do dia
    final entries = hive.getBox<MealEntry>('meal_entries').values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final now = DateTime.now();
    final todays = entries
        .where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day)
        .toList();
    _consumedKcal = todays.fold(0.0, (s, e) => s + e.calories);
    if (todays.isNotEmpty) {
      final after = todays.where((e) => e.dateTime.isAfter(now)).toList();
      _nextMeal = after.isNotEmpty ? after.first : todays.last;
    } else {
      _nextMeal = null;
    }

    // Meta diária vinda do perfil (campo correto)
    final profile = hive.getUserProfile();
    _dailyGoalKcal = (profile.dailyKcalGoal ?? 2000).toDouble();

    if (mounted) setState(() {});
  }

  void _startWorkout() {
    if (_nextSession == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutInProgressScreen(session: _nextSession!)),
    );
  }

  Future<void> _showAddMenu() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Adicionar Refeição por Câmera / Código de Barras'),
              onTap: () async {
                Navigator.pop(ctx);
                final barcode = await Navigator.push<String?>(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanBarcodeScreen()),
                );
                if (barcode != null) {
                  await _handleBarcode(barcode);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Adicionar Refeição por Texto (TACO)'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addMealByText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Adicionar Refeição com IA (texto)'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addMealByAIText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_front),
              title: const Text('Adicionar Refeição com IA (foto)'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoCaptureAIScreen()));
                _loadDashboard();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: const Text('Registrar Peso Corporal'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addWeight();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBarcode(String barcode) async {
    final hive = context.read<HiveService>();
    final mealsBox = hive.getBox<Meal>('meals');

    Meal? meal;
    try {
      meal = mealsBox.values.firstWhere((m) => m.id == barcode);
    } catch (_) {
      meal = null;
    }

    if (meal == null) {
      final api = FoodApiService();
      final fromApi = await api.fetchFoodByBarcode(barcode); 
      if (fromApi != null) {
        await mealsBox.add(fromApi);
        meal = fromApi;
      }
    }

    if (meal == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alimento não encontrado.')));
      return;
    }

    await _collectMealAmountAndSave(meal);
  }

  Future<void> _addMealByText() async {
    final foodRepo = context.read<FoodRepository>();
    final hive = context.read<HiveService>();
    final mealsBox = hive.getBox<Meal>('meals');

    final controller = TextEditingController();
    final labelController = TextEditingController(text: 'Almoço');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pesquisar alimento (TACO)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ex.: Peito de frango')),
            const SizedBox(height: 8),
            TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Rótulo (ex: Almoço)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final q = controller.text.trim();
              if (q.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final results = foodRepo.searchByName(q);
              Meal? meal;
              if (results.isNotEmpty) {
                meal = results.first;
                final exists = mealsBox.values.any((m) => m.id == meal!.id);
                if (!exists) await mealsBox.add(meal);
              }
              Navigator.pop(ctx);
              if (meal != null) {
                await _collectMealAmountAndSave(meal);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não encontrado no TACO.')));
              }
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMealByAIText() async {
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
              if (desc.isEmpty || grams == null || grams <= 0) {
                Navigator.pop(ctx);
                return;
              }

              final llm = context.read<LLMService>();
              if (!llm.isAvailable()) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure a IA no Perfil.')));
                return;
              }

              final ai = MealAIService(llm);
              final meal = await ai.fromText(desc);
              
              Navigator.pop(ctx);
              if (meal == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não retornou alimento.')));
                return;
              }

              final hive = context.read<HiveService>();
              await hive.getBox<Meal>('meals').add(meal);
              
              final newMealEntry = MealEntry(
                id: const Uuid().v4(),
                dateTime: DateTime.now(),
                label: labelCtl.text.isEmpty ? 'Refeição' : labelCtl.text.trim(),
                meal: meal,
                grams: grams,
              );
              await hive.getBox<MealEntry>('meal_entries').add(newMealEntry);
              
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MealDetailsScreen(mealEntry: newMealEntry)),
              ).then((_) => _loadDashboard());
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }


  Future<void> _collectMealAmountAndSave(Meal meal) async {
    final gramsCtl = TextEditingController();
    final labelCtl = TextEditingController(text: 'Almoço');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade - ${meal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: gramsCtl, decoration: const InputDecoration(labelText: 'Gramas (g)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: labelCtl, decoration: const InputDecoration(labelText: 'Rótulo (ex: Almoço)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final grams = double.tryParse(gramsCtl.text);
              if (grams == null || grams <= 0) {
                Navigator.pop(ctx);
                return;
              }
              final hive = context.read<HiveService>();
              
              // MUDANÇA: Removida a duplicação. Criamos e salvamos apenas uma vez.
              final newMealEntry = MealEntry(
                    id: const Uuid().v4(),
                    dateTime: DateTime.now(),
                    label: labelCtl.text.isEmpty ? 'Refeição' : labelCtl.text.trim(),
                    meal: meal,
                    grams: grams,
                  );
              await hive.getBox<MealEntry>('meal_entries').add(newMealEntry);
              
              Navigator.pop(ctx); // Fecha o dialog
              
              if (!mounted) return;

              // Navega para a tela de detalhes
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealDetailsScreen(mealEntry: newMealEntry),
                ),
              ).then((_) => _loadDashboard());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWeight() async {
    final ctl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Peso'),
        content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Peso (kg)'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final w = double.tryParse(ctl.text);
              if (w == null || w <= 0) {
                Navigator.pop(ctx);
                return;
              }
              final hive = context.read<HiveService>();
              await hive.getBox<WeightEntry>('weight_entries').add(
                    WeightEntry(id: const Uuid().v4(), dateTime: DateTime.now(), weightKg: w),
                  );
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peso registrado!')));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM, HH:mm');
    final progress = (_dailyGoalKcal > 0) ? (_consumedKcal / _dailyGoalKcal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do Dia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
                title: Text(_nextSession != null ? 'Próximo Treino: ${_nextSession!.name}' : 'Nenhum treino agendado'),
                subtitle: Text(_nextSession != null ? 'Dia: $_nextSessionDayName' : ''),
                trailing: ElevatedButton(
                  onPressed: _nextSession == null ? null : _startWorkout,
                  child: const Text('Começar'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant, color: Colors.orangeAccent),
                title: Text(_nextMeal != null ? 'Próxima Refeição: ${_nextMeal!.label}' : 'Sem refeição registrada'),
                subtitle: Text(_nextMeal != null ? '${_nextMeal!.meal.name} — ${dateFmt.format(_nextMeal!.dateTime)}' : ''),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Metas Calóricas', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Consumido: ${_consumedKcal.toStringAsFixed(0)} kcal'),
                    Text('Meta: ${_dailyGoalKcal.toStringAsFixed(0)} kcal'),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Refeição/Peso',
      ),
    );
  }
}
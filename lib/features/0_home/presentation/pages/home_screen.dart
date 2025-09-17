import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/models/models.dart';
import 'package:seu_app/features/common/scan_barcode_screen.dart';

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
  double _dailyGoalKcal = 2500; // pode vir do perfil/config

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    final hive = context.read<HiveService>();
    // Próximo treino: pega primeira rotina e calcula dia corrente
    final routines = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    if (routines.isNotEmpty) {
      final r = routines.first;
      final days = r.days.toList();
      if (days.isNotEmpty) {
        final today = DateTime.now();
        final diff = today.difference(r.startDate).inDays;
        final idx = diff >= 0 ? diff % days.length : 0;
        final day = days[idx];
        _nextSessionDayName = day.name;
        final sessions = day.sessions.toList();
        if (sessions.isNotEmpty) _nextSession = sessions.first;
      }
    }

    // Próxima refeição: procura MealEntry de hoje com horário após agora
    final entries = hive.getBox<MealEntry>('meal_entries').values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final now = DateTime.now();
    _nextMeal = entries.firstWhere((e) =>
        e.dateTime.year == now.year &&
        e.dateTime.month == now.month &&
        e.dateTime.day == now.day &&
        e.dateTime.isAfter(now), orElse: () => entries.lastWhere(
        (e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day,
        orElse: () => entries.isEmpty ? null : entries.last));

    // Calorias consumidas hoje
    _consumedKcal = entries.where((e) =>
      e.dateTime.year == now.year &&
      e.dateTime.month == now.month &&
      e.dateTime.day == now.day).fold(0.0, (s, e) => s + e.calories);

    setState(() {});
  }

  void _startWorkout() {
    if (_nextSession == null) return;
    // TODO: Navegar para tela de treino em progresso, passando a sessão _nextSession
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iniciando ${_nextSession!.name}')));
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
              title: const Text('Adicionar Refeição por Texto'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addMealByText();
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

    // tenta encontrar no local
    final localMeal = mealsBox.values.firstWhere(
      (m) => m.id == barcode, orElse: () => Meal(
        id: '', name: '', description: '', caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0));
    Meal? meal = localMeal.id.isEmpty ? null : localMeal;

    if (meal == null) {
      // fallback para OpenFoodFacts
      final fromApi = await Future.microtask(() async {
        // instancia local para evitar acoplamento
        final service = se u_app.core.services.food_api_service.FoodApiService();
        return service.fetchFoodByBarcode(barcode);
      });
      if (fromApi != null) {
        await mealsBox.add(fromApi);
        meal = fromApi;
      }
    }

    if (meal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alimento não encontrado.')));
      return;
    }

    await _collectMealAmountAndSave(meal);
  }

  Future<void> _addMealByText() async {
    final hive = context.read<HiveService>();
    final foodRepo = context.read<seu_app.core.services.food_repository.FoodRepository>();
    final mealsBox = hive.getBox<Meal>('meals');

    final controller = TextEditingController();
    final labelController = TextEditingController(text: 'Almoço');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pesquisar alimento'),
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
          TextButton(onPressed: () async {
            final q = controller.text.trim();
            if (q.isEmpty) { Navigator.pop(ctx); return; }
            final results = foodRepo.searchByName(q);
            Meal? meal;
            if (results.isNotEmpty) {
              meal = results.first;
              // opcional: salvar cópia local
              final exists = mealsBox.values.any((m) => m.id == meal!.id);
              if (!exists) await mealsBox.add(meal);
            }
            // TODO (opcional): se não achar, chamar LLM para inferir macros pela descrição
            Navigator.pop(ctx);
            if (meal != null) await _collectMealAmountAndSave(meal);
          }, child: const Text('Ok')),
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
          TextButton(onPressed: () async {
            final grams = double.tryParse(gramsCtl.text);
            if (grams == null || grams <= 0) { Navigator.pop(ctx); return; }
            final entry = MealEntry(
              id: const Uuid().v4(),
              dateTime: DateTime.now(),
              label: labelCtl.text.isEmpty ? 'Refeição' : labelCtl.text.trim(),
              meal: meal,
              grams: grams,
            );
            final hive = context.read<HiveService>();
            await hive.getBox<MealEntry>('meal_entries').add(entry);
            Navigator.pop(ctx);
            _loadDashboard();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refeição registrada!')));
          }, child: const Text('Salvar')),
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
          TextButton(onPressed: () async {
            final w = double.tryParse(ctl.text);
            if (w == null || w <= 0) { Navigator.pop(ctx); return; }
            final hive = context.read<HiveService>();
            await hive.getBox<WeightEntry>('weight_entries').add(
              WeightEntry(id: const Uuid().v4(), dateTime: DateTime.now(), weightKg: w),
            );
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peso registrado!')));
          }, child: const Text('Salvar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM, HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do Dia'),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () {
            // Abra seu ProfileScreen pelo MainScaffold ou Navigator
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
                title: Text(_nextSession != null
                    ? 'Próximo Treino: ${_nextSession!.name}'
                    : 'Nenhum treino agendado'),
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
                  LinearProgressIndicator(value: (_consumedKcal / _dailyGoalKcal).clamp(0.0, 1.0)),
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

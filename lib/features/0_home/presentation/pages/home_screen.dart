import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fitapp/core/models/models.dart';
import 'package:fitapp/core/services/hive_service.dart';
import 'package:fitapp/core/services/food_api_service.dart';
import 'package:fitapp/core/services/food_repository.dart';
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/meal_ai_service.dart';
import 'package:fitapp/core/utils/diet_schedule_utils.dart';

import 'package:fitapp/features/common/scan_barcode_screen.dart';
import 'package:fitapp/features/1_workout_tracker/presentation/pages/workout_in_progress_screen.dart';
import 'package:fitapp/features/5_nutrition/presentation/pages/meal_details_screen.dart';
import 'package:fitapp/features/7_settings/presentation/pages/settings_screen.dart';
import 'package:fitapp/features/3_planner/presentation/pages/new_plan_flow_screen.dart';
import 'package:fitapp/features/3_planner/domain/value_objects/slug.dart';

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
  String? _dietGoalLabel;
  String? _dietWeightGoal;

  bool _planEnded = false;

  static const int _defaultDurationDays = 180;

  final _kpiCtl = PageController();
  int _kpiIndex = 0;

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime _defaultEndFor(DateTime start) =>
      _dateOnly(start.add(const Duration(days: _defaultDurationDays - 1)));

  DateTime? _resolveScheduleEndDate({
    required DateTime? start,
    required DateTime? storedEnd,
  }) {
    if (start == null) return null;
    final startOnly = _dateOnly(start);
    if (storedEnd != null) {
      final normalized = _dateOnly(storedEnd);
      if (!normalized.isBefore(startOnly)) {
        return normalized;
      }
    }
    return _defaultEndFor(startOnly);
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _kpiCtl.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    final hive = context.read<HiveService>();
    _nextSession = null;
    _nextSessionDayName = '';
    _planEnded = false;

    // Próximo treino pela primeira rotina
    final routines = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    if (routines.isNotEmpty) {
      final r = routines.first;
      final days = r.days.toList();
      if (days.isNotEmpty) {
        final routineStart = _dateOnly(r.startDate);
        final today = _dateOnly(DateTime.now());
        final scheduleBox = hive.getBox<WorkoutRoutineSchedule>('routine_schedules');
        final slug = toSlug(r.name);
        final scheduleMatches =
            scheduleBox.values.where((s) => s.routineSlug == slug).toList();
        final schedule = scheduleMatches.isEmpty ? null : scheduleMatches.first;
        final endDate = _resolveScheduleEndDate(
          start: routineStart,
          storedEnd: schedule?.endDate,
        );

        _planEnded = endDate != null && today.isAfter(endDate);

        if (!_planEnded) {
          final diff = today.difference(routineStart).inDays;
          final idx = diff >= 0 && days.isNotEmpty ? diff % days.length : 0;
          final day = days[idx];
          _nextSessionDayName = day.name;
          final sessions = day.sessions.toList();
          if (sessions.isNotEmpty) {
            _nextSession = sessions.first;
          } else {
            _nextSession = null;
          }
        } else {
          _nextSessionDayName = '';
          _nextSession = null;
        }
      }
    }

    // Próxima refeição e kcal do dia
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

    final profile = hive.getUserProfile();
    _dailyGoalKcal = (profile.dailyKcalGoal ?? 2000).toDouble();
    _dietGoalLabel = null;
    _dietWeightGoal = null;

    final dietTarget = DietScheduleUtils.resolveDailyTarget(hive: hive);
    if (dietTarget != null) {
      final label = dietTarget.displayLabel;
      if (label != null) {
        _dietGoalLabel = label;


      }
      if (dietTarget.hasCalorieGoal) {
        _dailyGoalKcal = dietTarget.calories;
      }
      _dietWeightGoal = dietTarget.weightGoal;
    }

    if (mounted) setState(() {});
  }

  void _startWorkout() {
    if (_nextSession == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutInProgressScreen(session: _nextSession!)));
  }

  void _startWorkoutWith(WorkoutSession s) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutInProgressScreen(session: s)));
  }

  Future<void> _showUpcomingWorkouts() async {
    final hive = context.read<HiveService>();
    final routines = hive.getBox<WorkoutRoutine>('workout_routines').values.toList();
    if (routines.isEmpty || routines.first.days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma rotina encontrada.')));
      return;
    }
    final r = routines.first;
    final days = r.days.toList();
    final scheduleBox = hive.getBox<WorkoutRoutineSchedule>('routine_schedules');
    final slug = toSlug(r.name);
    final scheduleMatches = scheduleBox.values.where((s) => s.routineSlug == slug).toList();
    final schedule = scheduleMatches.isEmpty ? null : scheduleMatches.first;

    final routineStart = _dateOnly(r.startDate);
    final now = _dateOnly(DateTime.now());
    final endDate = _resolveScheduleEndDate(start: routineStart, storedEnd: schedule?.endDate);

    if (endDate != null && now.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plano concluído. Gere uma nova rotina com a IA.')),
      );
      return;
    }

    final items = <({DateTime date, WorkoutSession session, String dayName})>[];
    for (int i = 0; i < min(10, days.length * 2); i++) {
      final date = _dateOnly(now.add(Duration(days: i)));
      if (endDate != null && date.isAfter(endDate)) break;
      final diff = date.difference(routineStart).inDays;
      if (diff < 0) continue;
      final idx = days.isEmpty ? 0 : diff % days.length;
      final d = days[idx];
      if (d.sessions.isEmpty) continue;
      items.add((date: date, session: d.sessions.first, dayName: d.name));
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Próximos treinos')),
            for (final it in items)
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text('${it.dayName} • ${it.session.name}'),
                subtitle: Text(DateFormat('EEE, dd/MM').format(it.date)),
                trailing: TextButton(
                  child: const Text('Iniciar'),
                  onPressed: () {
                    Navigator.pop(context);
                    _startWorkoutWith(it.session);
                  },
                ),
              ),
          ],
        ),
      ),
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

              final hive = context.read<HiveService>();
              final dietTarget = DietScheduleUtils.resolveDailyTarget(hive: hive);
              final bias = DietScheduleUtils.calorieBiasForGoal(
                dietTarget?.weightGoal ?? _dietWeightGoal,
              );

              final ai = MealAIService(llm);
              final meal = await ai.fromText(desc, calorieBias: bias);

              Navigator.pop(ctx);
              if (meal == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA não retornou alimento.')));
                return;
              }

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
              final newMealEntry = MealEntry(
                id: const Uuid().v4(),
                dateTime: DateTime.now(),
                label: labelCtl.text.isEmpty ? 'Refeição' : labelCtl.text.trim(),
                meal: meal,
                grams: grams,
              );
              await hive.getBox<MealEntry>('meal_entries').add(newMealEntry);
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MealDetailsScreen(mealEntry: newMealEntry)),
              ).then((_) => _loadDashboard());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  double _monthCalories() {
    final hive = context.read<HiveService>();
    final now = DateTime.now();
    final entries = hive.getBox<MealEntry>('meal_entries').values.where((e) =>
        e.dateTime.year == now.year && e.dateTime.month == now.month);
    return entries.fold(0.0, (s, e) => s + e.calories);
  }

  Map<DateTime, double> _dailyVolume({bool cardio = false}) {
    final hive = context.read<HiveService>();
    final sets = hive.getBox<WorkoutSetEntry>('workout_set_entries').values.toList();

    final byDay = <DateTime, double>{};
    for (final s in sets) {
      final day = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
      double add = 0;
      if (cardio) {
        add = (s.metrics['Distância'] ?? 0).toDouble();
      } else {
        final w = (s.metrics['Peso'] ?? 0).toDouble();
        final r = (s.metrics['Repetições'] ?? 0).toDouble();
        add = w * r;
      }
      byDay.update(day, (v) => v + add, ifAbsent: () => add);
    }
    return byDay;
  }

  Widget _miniBars(Map<DateTime, double> data) {
    if (data.isEmpty) return const Text('Sem dados');
    final days = data.keys.toList()..sort();
    final vals = days.map((d) => data[d]!).toList();
    final maxV = vals.fold<double>(0, max);
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in vals)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(height: maxV == 0 ? 2.0 : max(2.0, 70.0 * (v / maxV)), color: Colors.blueGrey),
              ),
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
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _planEnded
                                ? 'Plano concluído'
                                : _nextSession != null
                                    ? 'Próximo Treino'
                                    : 'Nenhum treino agendado',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_planEnded) ...[
                            const SizedBox(height: 4),
                            const Text('Seu plano atual foi concluído. Gere uma nova rotina para continuar os treinos.'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NewPlanFlowScreen()),
                              ),
                              child: const Text('Criar novo plano'),
                            ),
                          ] else if (_nextSession != null) ...[
                            const SizedBox(height: 4),
                            Text('${_nextSession!.name}  •  Dia: $_nextSessionDayName'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(onPressed: _startWorkout, child: const Text('Iniciar')),
                                const SizedBox(width: 8),
                                OutlinedButton(onPressed: _showUpcomingWorkouts, child: const Text('Próximos')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Próxima Refeição', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(_nextMeal != null
                              ? '${_nextMeal!.label} — ${_nextMeal!.meal.name}\n${dateFmt.format(_nextMeal!.dateTime)}'
                              : 'Sem refeição registrada'),
                          const SizedBox(height: 12),
                          Row(children: [
                            ElevatedButton(onPressed: _showAddMenu, child: const Text('Adicionar Refeição')),
                            const SizedBox(width: 8),
                            OutlinedButton(onPressed: _addWeight, child: const Text('Novo Peso')),
                          ]),
                          const Divider(height: 20),
                          Text('Calorias hoje: ${_consumedKcal.toStringAsFixed(0)} / ${_dailyGoalKcal.toStringAsFixed(0)} kcal'),
                          if (_dietGoalLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Plano: $_dietGoalLabel',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Planejar nova rotina'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPlanFlowScreen())),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Evolução', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: PageView(
                      controller: _kpiCtl,
                      onPageChanged: (i) => setState(() => _kpiIndex = i),
                      children: [
                        _KpiCard(title: 'Cargas dos treinos', child: _miniBars(_dailyVolume())),
                        _KpiCard(title: 'Evolução cardio (distância)', child: _miniBars(_dailyVolume(cardio: true))),
                        _KpiCard(title: 'Evolução do peso', child: _WeightMiniChart()),
                        _KpiCard(title: 'Calorias no mês', child: Text('${_monthCalories().toStringAsFixed(0)} kcal')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(4, (i) => Icon(i == _kpiIndex ? Icons.circle : Icons.circle_outlined, size: 10)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _TopMusclesCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Refeição',
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peso registrado')));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(child: Center(child: child)),
        ]),
      ),
    );
  }
}

class _WeightMiniChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hive = context.read<HiveService>();
    final data = hive.getBox<WeightEntry>('weight_entries').values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (data.isEmpty) return const Text('Sem dados');
    final minW = data.map((e) => e.weightKg).reduce(min);
    final maxW = data.map((e) => e.weightKg).reduce(max);
    final span = (maxW - minW).abs() < 0.001 ? 1.0 : (maxW - minW);
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: max(2.0, 70.0 * ((e.weightKg - minW) / span)),
                  color: Colors.teal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopMusclesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hive = context.read<HiveService>();
    final sets = hive.getBox<WorkoutSetEntry>('workout_set_entries').values.toList();
    final exBox = hive.getBox<Exercise>('exercises');

    final now = DateTime.now();
    final monthSets = sets.where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month);

    final volumeByMuscle = <String, double>{};
    for (final s in monthSets) {
      final matches = exBox.values.where((e) => e.id == s.exerciseId);
      final Exercise? ex = matches.isNotEmpty ? matches.first : null;
      if (ex == null) continue;

      final vol = (s.metrics['Peso'] ?? 0).toDouble() * (s.metrics['Repetições'] ?? 0).toDouble();
      for (final m in ex.primaryMuscles) {
        volumeByMuscle.update(m, (v) => v + vol, ifAbsent: () => vol);
      }
    }

    final entries = volumeByMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(8).toList();
    final total = top.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Músculos mais treinados no mês', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (top.isEmpty)
            const Text('Sem dados')
          else
            Column(
              children: [
                for (final e in top)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 120, child: Text(e.key)),
                        Expanded(
                          child: LinearProgressIndicator(value: total == 0 ? 0 : (e.value / total)),
                        ),
                        const SizedBox(width: 8),
                        Text('${total == 0 ? 0 : (100 * e.value / total).round()}%'),
                      ],
                    ),
                  ),
              ],
            ),
        ]),
      ),
    );
  }
}

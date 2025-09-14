import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/nutrition_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/nutrition/header_cards.dart';
import '../../widgets/nutrition/weekly_delta_chart.dart';
import '../../widgets/nutrition/day_meals_section.dart';
import '../../widgets/nutrition/add_meal_sheet.dart';

class NutritionDashboardScreen extends ConsumerWidget {
  const NutritionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAV   = ref.watch(todaySummaryProvider);
    final weeklyAV  = ref.watch(weeklyDeltaProvider);
    final weightAV  = ref.watch(weightProgressProvider);
    final plannedAV = ref.watch(plannedMealsTodayProvider);
    final eatenAV   = ref.watch(consumedMealsTodayProvider);

    Future<void> _refresh() async => ref.invalidateNutrition();

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrição')),
      drawer: const AppNavDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            todayAV.when(
              data: (t) => weightAV.when(
                data: (w) => HeaderCards(
                  kcalToday: t.kcal, p: t.p, c: t.c, f: t.f,
                  targetKcal: t.targetKcal,
                  weightNow: w.current, targetWeight: w.target, weightTrendOk: w.trendOk,
                ),
                loading: () => const _SkeletonHeader(),
                error: (_, __) => const _SkeletonHeader(),
              ),
              loading: () => const _SkeletonHeader(),
              error: (_, __) => const _SkeletonHeader(),
            ),
            const SizedBox(height: 12),

            // Ações rápidas
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: const Text('Histórico'),
                  onPressed: () => context.go('/nutrition/history'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Rotinas'),
                  onPressed: () => context.go('/nutrition/routines'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan código'),
                  onPressed: () => context.go('/nutrition/scan'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Adicionar (texto)'),
                  onPressed: () => context.go('/nutrition/add?tab=text'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Adicionar (foto/IA)'),
                  onPressed: () => context.go('/nutrition/add?tab=photo'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Semana: superávit/déficit (kcal)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: WeeklyDeltaChart(
                        deltas: weeklyAV.maybeWhen(data: (l) => l, orElse: () => const <double>[]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            DayMealsSection(
              planned: plannedAV.maybeWhen(data: (v) => v, orElse: () => const []),
              consumed: eatenAV.maybeWhen(data: (v) => v, orElse: () => const []),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMealSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar refeição'),
      ),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();
  @override
  Widget build(BuildContext context) => Card(child: Container(height: 96, padding: const EdgeInsets.all(16)));
}

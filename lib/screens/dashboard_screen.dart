// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/providers/dashboard_providers.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const AppNavDrawer(),
      body: summaryAsync.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de Nutrição
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nutrição Hoje', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: summary.kcalProgress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Text('${summary.nutrition.consumedKcal.round()} / ${summary.nutrition.targetKcal.round()} kcal'),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/nutrition'),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Refeição'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card de Treino
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treino', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    summary.hasActiveWorkout
                        ? const Text('Sessão de treino em andamento.')
                        : const Text('Nenhum treino planejado para hoje.'),
                    const SizedBox(height: 16),
                     Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                           if(summary.hasActiveWorkout) {
                             // context.go('/workout/active'); // Rota a ser criada
                           } else {
                             context.go('/planner');
                           }
                        },
                        icon: Icon(summary.hasActiveWorkout ? Icons.directions_run : Icons.play_arrow),
                        label: Text(summary.hasActiveWorkout ? 'Retomar Treino' : 'Iniciar Treino'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
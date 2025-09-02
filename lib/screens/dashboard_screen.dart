import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../providers/workout_logic.dart';
import '../widgets/widgets.dart';
import '../widgets/app_drawer.dart';
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todays = ref.watch(todaysWorkoutProvider);
    final cal = ref.watch(calorieStatusProvider);
    final xp = ref.watch(xpProvider);
    final neglected = ref.watch(neglectedMusclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        IconButton(onPressed: ()=> context.go('/settings'), icon: const Icon(Icons.settings))
      ]),
      
      drawer: const AppNavDrawer(),
      
      body: ListView(padding: const EdgeInsets.all(16), children: [
        StatCard(
          title: 'Treino de hoje',
          subtitle: todays == null ? 'Descanso' : todays['name'],
          icon: Icons.fitness_center,
          trailing: todays == null ? null : ElevatedButton(
            onPressed: ()=> context.go('/workout/${todays['id']}'),
            child: const Text('Iniciar'),
          ),
        ),
        StatCard(
          title: 'Calorias (Meta × Consumido × Gasto)',
          subtitle: '${cal.target.toStringAsFixed(0)} × ${cal.consumed.toStringAsFixed(0)} × ${cal.burned.toStringAsFixed(0)} kcal',
          icon: Icons.local_dining,
          trailing: Text(
            '${cal.balance >= 0 ? '+' : ''}${cal.balance.toStringAsFixed(0)} kcal',
            style: TextStyle(color: cal.balance>=0? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
        StatCard(title: 'XP', subtitle: '$xp', icon: Icons.star),
        if (neglected.isNotEmpty)
          StatCard(title: 'Músculos pouco treinados', subtitle: neglected.join(', '), icon: Icons.info_outline),
      ]),
    );
  }
}

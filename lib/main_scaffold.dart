// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/hive_service.dart';

import 'features/0_home/presentation/pages/home_screen.dart';
import 'features/4_workouts/presentation/pages/workouts_hub_screen.dart';
import 'features/3_planner/presentation/pages/planner_screen.dart';
import 'features/5_nutrition/presentation/pages/nutrition_hub_screen.dart';
import 'features/6_databases/presentation/pages/databases_screen.dart';
import 'features/7_settings/presentation/pages/settings_screen.dart';
import 'features/2_profile/presentation/pages/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _titles = const [
    'Início','Treinos','Planejador','Nutrição','Bases de Dados','Configurações','Perfil'
  ];

  late final List<Widget> _pages = const [
    HomeScreen(),
    WorkoutsHubScreen(),
    PlannerScreen(),
    NutritionHubScreen(),
    DatabasesScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  void _go(int i) {
    setState(() => _index = i);
    Navigator.pop(context); // fecha o drawer
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<HiveService>().getUserProfile();

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      // Com drawer definido, o ícone de “3 risquinhos” aparece automaticamente
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(profile.name.isEmpty ? 'Seu Perfil' : profile.name),
                accountEmail: Text(profile.gender ?? ''),
                currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
              ),
              _item(Icons.home,             'Início',         0),
              _item(Icons.fitness_center,   'Treinos',        1),
              _item(Icons.event,            'Planejador',     2),
              _item(Icons.restaurant,       'Nutrição',       3),
              _item(Icons.storage,          'Bases de Dados', 4),
              const Divider(),
              _item(Icons.settings,         'Configurações',  5),
              _item(Icons.person,           'Perfil',         6),
            ],
          ),
        ),
      ),
      body: _pages[_index],
    );
  }

  Widget _item(IconData icon, String label, int i) {
    final selected = _index == i;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () => _go(i),
    );
  }
}

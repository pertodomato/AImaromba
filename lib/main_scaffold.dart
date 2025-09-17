import 'package:flutter/material.dart';
import 'package:seu_app/features/0_home/presentation/pages/home_screen.dart';
import 'package:seu_app/features/3_planner/presentation/pages/planner_screen.dart';
import 'package:seu_app/features/4_workouts/presentation/pages/workouts_hub_screen.dart';
import 'package:seu_app/features/5_nutrition/presentation/pages/nutrition_hub_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // Lista das telas principais que serão controladas pela barra de navegação
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    WorkoutsHubScreen(),
    NutritionHubScreen(),
    PlannerScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Principal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Treinos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Nutrição',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planejador',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey, // Garante que itens não selecionados fiquem visíveis no tema escuro
        type: BottomNavigationBarType.fixed, // Mantém o fundo fixo
        onTap: _onItemTapped,
      ),
    );
  }
}
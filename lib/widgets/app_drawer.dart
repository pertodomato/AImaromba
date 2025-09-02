import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('FitApp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            ListTile(leading: const Icon(Icons.dashboard),       title: const Text('Dashboard'),      onTap: () => context.go('/dashboard')),
            ListTile(leading: const Icon(Icons.map),             title: const Text('Mapa Muscular'),  onTap: () => context.go('/muscle')),
            ListTile(leading: const Icon(Icons.library_books),   title: const Text('Biblioteca'),     onTap: () => context.go('/library')),
            ListTile(leading: const Icon(Icons.build),           title: const Text('Sessões de Treino (IA)'), onTap: () => context.go('/criar_treinos')),
            ListTile(leading: const Icon(Icons.calendar_month),  title: const Text('Planejador'),     onTap: () => context.go('/planner')),
            ListTile(leading: const Icon(Icons.restaurant),      title: const Text('Nutrição'),       onTap: () => context.go('/nutrition')),
            ListTile(leading: const Icon(Icons.history),         title: const Text('Histórico'),      onTap: () => context.go('/history')),
            ListTile(leading: const Icon(Icons.person),          title: const Text('Perfil & Backup'),onTap: () => context.go('/profile')),
            ListTile(leading: const Icon(Icons.settings),        title: const Text('Configurações'),  onTap: () => context.go('/settings')),
          ],
        ),
      ),
    );
  }
}

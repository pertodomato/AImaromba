import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('FitApp',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => _go(context, '/dashboard'),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Análise Muscular'),
              onTap: () => _go(context, '/muscle'),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Biblioteca'),
              onTap: () => _go(context, '/library'),
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Sessões de Treino (IA)'),
              onTap: () => _go(context, '/criar_treinos'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Planejador'),
              onTap: () => _go(context, '/planner'),
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Nutrição'),
              onTap: () => _go(context, '/nutrition'),
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil & Backup'),
              onTap: () => _go(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configurações'),
              onTap: () => _go(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

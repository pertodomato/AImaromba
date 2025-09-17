import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Tema Escuro'),
            value: theme.isDark,
            onChanged: (v) => context.read<ThemeService>().setDark(v),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sobre o App'),
          ),
        ],
      ),
    );
  }
}

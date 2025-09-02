import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/util.dart'; // kBoxes
import '../widgets/app_drawer.dart'; // + import

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool dark = Hive.box('settings').get('darkMode', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      drawer: const AppNavDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Tema escuro'),
            value: dark,
            onChanged: (v) {
              setState(() => dark = v);
              Hive.box('settings').put('darkMode', v);
            },
          ),
          const Divider(),
          const Text('Boxes (tamanho atual):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...kBoxes.map((name) {
            final opened = Hive.isBoxOpen(name);
            final len = opened ? Hive.box(name).length : 0;
            return ListTile(dense: true, title: Text(name), trailing: Text('$len'));
          }),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              for (final b in kBoxes) {
                if (Hive.isBoxOpen(b)) await Hive.box(b).clear();
              }
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Todos os dados foram apagados.')));
                setState(() {});
              }
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Apagar TODOS os dados'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

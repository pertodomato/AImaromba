import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:fitapp/services/ai/ai_core_service.dart';
import 'package:fitapp/services/ai/exercise_prompt_service.dart';

import '../widgets/app_drawer.dart'; // + import

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();
  final _form = GlobalKey<FormState>();

  final _gender = ValueNotifier<String>('M');
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  final _apiKeyCtrl = TextEditingController(text: AICore.defaultKey);

  @override
  void initState() {
    super.initState();
    final p = Hive.box('profile');
    _gender.value = p.get('gender', defaultValue: 'M');
    _ageCtrl.text = '${p.get('age', defaultValue: 25)}';
    _weightCtrl.text = '${p.get('weight', defaultValue: 75.0)}';
    _heightCtrl.text = '${p.get('height', defaultValue: 175.0)}';
    _calCtrl.text = '${p.get('calorieTarget', defaultValue: 2200)}';
    _loadKey();
  }

  Future<void> _loadKey() async {
    final saved = (await _storage.read(key: 'openai_api_key'))?.trim() ?? '';
    if (saved.isNotEmpty) {
      _apiKeyCtrl.text = saved;
      setState(() {});
    } else {
      // se não havia nada salvo, já grava a default para evitar 401
      await _storage.write(key: 'openai_api_key', value: AICore.defaultKey);
    }
  }

  Future<void> _saveProfile() async {
    if (!_form.currentState!.validate()) return;
    final p = Hive.box('profile');
    p.putAll({
      'gender': _gender.value,
      'age': int.tryParse(_ageCtrl.text) ?? 25,
      'weight': double.tryParse(_weightCtrl.text) ?? 75.0,
      'height': double.tryParse(_heightCtrl.text) ?? 175.0,
      'calorieTarget': int.tryParse(_calCtrl.text) ?? 2200,
    });
    await _storage.write(key: 'openai_api_key', value: _apiKeyCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil salvo.')));
    }
  }

  Future<void> _testAI() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testando IA…')));
    final res = await ExercisePromptService.generateExerciseFromText('Corrida leve ao ar livre; medir distância e tempo.');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res != null ? 'OK: ${res['name']}' : 'Falhou (verifique a chave)'),
    ));
  }

  @override
  void dispose() {
    _ageCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose(); _calCtrl.dispose(); _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil & Backup')),
      drawer: const AppNavDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(children: [
            Row(children: [
              const Text('Sexo:  '),
              ValueListenableBuilder<String>(
                valueListenable: _gender,
                builder: (_, v, __) => SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'M', label: Text('M')),
                    ButtonSegment(value: 'F', label: Text('F')),
                  ],
                  selected: {v},
                  onSelectionChanged: (s) => _gender.value = s.first,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(controller: _ageCtrl, decoration: const InputDecoration(labelText: 'Idade'), keyboardType: TextInputType.number),
            TextFormField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Peso (kg)'), keyboardType: TextInputType.number),
            TextFormField(controller: _heightCtrl, decoration: const InputDecoration(labelText: 'Altura (cm)'), keyboardType: TextInputType.number),
            TextFormField(controller: _calCtrl, decoration: const InputDecoration(labelText: 'Meta calórica (kcal/dia)'), keyboardType: TextInputType.number),
            const Divider(height: 24),
            TextFormField(
              controller: _apiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'OpenAI API Key',
                helperText: 'Usando uma padrão; edite se quiser a sua.',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ElevatedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save), label: const Text('Salvar')),
              OutlinedButton.icon(onPressed: _testAI, icon: const Icon(Icons.bolt), label: const Text('Testar chamada')),
            ]),
          ]),
        ),
      ),
    );
  }
}

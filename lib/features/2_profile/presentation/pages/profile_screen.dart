import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/models/user_profile.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/services/llm_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserProfile _userProfile;
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _birthDateController;
  late TextEditingController _bodyFatController;
  late String _selectedGender;
  late TextEditingController _geminiApiKeyController;
  late TextEditingController _gptApiKeyController;
  String _selectedLlmProvider = 'gemini';

  // metas de nutrição
  late TextEditingController _dailyKcalController;
  late TextEditingController _dailyProteinController;

  bool _checking = false;
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _userProfile = context.read<HiveService>().getUserProfile();
    _nameController = TextEditingController(text: _userProfile.name);
    _heightController = TextEditingController(text: _userProfile.height?.toString() ?? '');
    _weightController = TextEditingController(text: _userProfile.weight?.toString() ?? '');
    _birthDateController =
        TextEditingController(text: _userProfile.birthDate == null ? '' : _userProfile.birthDate!.toIso8601String().split('T').first);
    _bodyFatController = TextEditingController(text: _userProfile.bodyFatPercentage?.toString() ?? '');
    _selectedGender = _userProfile.gender ?? 'Other';
    _geminiApiKeyController = TextEditingController(text: _userProfile.geminiApiKey);
    _gptApiKeyController = TextEditingController(text: _userProfile.gptApiKey);
    _selectedLlmProvider = _userProfile.selectedLlm;

    _dailyKcalController = TextEditingController(text: _userProfile.dailyKcalGoal?.toString() ?? '');
    _dailyProteinController = TextEditingController(text: _userProfile.dailyProteinGoal?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _birthDateController.dispose();
    _bodyFatController.dispose();
    _geminiApiKeyController.dispose();
    _gptApiKeyController.dispose();
    _dailyKcalController.dispose();
    _dailyProteinController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = UserProfile(
        name: _nameController.text.trim(),
        height: double.tryParse(_heightController.text.trim()),
        weight: double.tryParse(_weightController.text.trim()),
        birthDate: DateTime.tryParse(_birthDateController.text.trim()),
        gender: _selectedGender,
        bodyFatPercentage: double.tryParse(_bodyFatController.text.trim()),
        geminiApiKey: _geminiApiKeyController.text.trim(),
        gptApiKey: _gptApiKeyController.text.trim(),
        selectedLlm: _selectedLlmProvider,
        dailyKcalGoal: double.tryParse(_dailyKcalController.text.trim()),
        dailyProteinGoal: double.tryParse(_dailyProteinController.text.trim()),
      );
      final hiveService = context.read<HiveService>();
      hiveService.saveUserProfile(updatedProfile);
      context.read<LLMService>().initialize(updatedProfile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil salvo')));
    }
  }

  Future<void> _checkLLM() async {
    setState(() => _checking = true);
    final ok = await context.read<LLMService>().ping();
    setState(() {
      _connected = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _checking
        ? const Text('Testando...', style: TextStyle(color: Colors.amber))
        : (_connected == true
            ? const Text('Conectado', style: TextStyle(color: Colors.green))
            : (_connected == false ? const Text('Desconectado', style: TextStyle(color: Colors.red)) : const Text('')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
          IconButton(icon: const Icon(Icons.power), onPressed: _checkLLM, tooltip: 'Testar LLM'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text('Status LLM: '), status]),
            const SizedBox(height: 12),
            Text('Informações Pessoais', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome')),
            TextFormField(controller: _heightController, decoration: const InputDecoration(labelText: 'Altura (cm)'), keyboardType: TextInputType.number),
            TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: 'Peso (kg)'), keyboardType: TextInputType.number),
            TextFormField(controller: _birthDateController, decoration: const InputDecoration(labelText: 'Nascimento (AAAA-MM-DD)')),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Sexo'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Masculino')),
                DropdownMenuItem(value: 'Female', child: Text('Feminino')),
                DropdownMenuItem(value: 'Other', child: Text('Outro')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value!),
            ),
            TextFormField(controller: _bodyFatController, decoration: const InputDecoration(labelText: '% Gordura Corporal'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Text('Metas de Nutrição', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dailyKcalController,
              decoration: const InputDecoration(labelText: 'Meta diária de calorias (kcal)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _dailyProteinController,
              decoration: const InputDecoration(labelText: 'Meta diária de proteína (g)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Text('Configurações da IA', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLlmProvider,
              decoration: const InputDecoration(labelText: 'Provedor de IA'),
              items: const [
                DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                DropdownMenuItem(value: 'gpt', child: Text('OpenAI GPT')),
              ],
              onChanged: (value) => setState(() => _selectedLlmProvider = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _geminiApiKeyController, decoration: const InputDecoration(labelText: 'Chave API Gemini'), obscureText: true),
            const SizedBox(height: 16),
            TextFormField(controller: _gptApiKeyController, decoration: const InputDecoration(labelText: 'Chave API OpenAI (GPT)'), obscureText: true),
          ]),
        ),
      ),
    );
  }
}

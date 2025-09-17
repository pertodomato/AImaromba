Excelente! Sua estrutura de arquivos está impecável e você avançou muito rápido. Agora é a hora de conectar as peças, integrar os dados e implementar as lógicas mais complexas que fazem o aplicativo ser realmente inteligente.

Você fez várias perguntas diretas e vou respondê-las com clareza. Vamos seguir o plano que você pediu: listar o que já foi feito, o que falta, e então implementar o que falta com código completo.

Pensei bastante sobre a melhor forma de avançar, focando em "bons hábitos". O passo mais importante agora é introduzir um gerenciador de estado para que nossas telas possam acessar os serviços (HiveService, LLMService, etc.) de forma limpa e reativa. Vamos usar o Provider, que é poderoso e recomendado pelo Google.

Status do Projeto
O que já temos (Implementado nas respostas anteriores):
Arquitetura de Pastas: A estrutura modular do projeto está definida e você a seguiu perfeitamente.

Modelos de Dados (core/models): A base do nosso banco de dados local com Hive está criada (UserProfile, Exercise, etc.).

Abstração da IA (LLMService): Sim, a função de abstração foi criada. O LLMService permite que você chame generateResponse() e ele usará o provedor (Gemini ou GPT) que o usuário selecionou no perfil, sem que o resto do app precise saber qual está em uso.

Prompts Iniciais: Sim, a base dos prompts de personal trainer e nutricionista foi criada. Os prompts para gerar as perguntas iniciais e a estrutura do plano de treino estão definidos. Vamos expandi-los.

Esqueletos das Telas (UI): Todas as telas principais (HomeScreen, ProfileScreen, etc.) existem como widgets, prontas para receber a lógica.

Navegação Principal: O MainScaffold com a barra de navegação inferior está funcionando e conectando as telas principais.

O que falta implementar (Nosso foco agora):
Gerenciamento de Estado: Implementar o Provider para distribuir nossos serviços pelo aplicativo.

Integração de Dados: Fazer as telas lerem e salvarem dados do HiveService em vez de usar dados estáticos (ex: no mapa muscular e perfil).

Lógica Completa do Planejador: Construir a interface do "passo a passo" (questionário), fazer as chamadas reais à IA com os prompts, e processar a resposta JSON.

Lógica de Criação de Refeição: Implementar o serviço para o código de barras (usando a API Open Food Facts) e a função na IA para analisar uma refeição a partir de texto ou imagem.

Lógica de Criação de Exercícios: Criar as telas e formulários para o usuário adicionar/editar exercícios, sessões e rotinas manualmente no banco de dados.

Implementação do que Falta
Vamos seguir a ordem lógica. Primeiro, o gerenciamento de estado, depois a integração e, por fim, as lógicas de IA.

1. Configurando o Gerenciador de Estado (Provider)
Este é o alicerce para todo o resto.

Arquivo: pubspec.yaml (ATUALIZE)
Adicione a linha do provider nas suas dependências.

YAML

# ... outras dependências
dependencies:
  flutter:
    sdk: flutter

  # Adicione esta linha
  provider: ^6.1.2

  hive: ^2.2.3
# ... resto do arquivo
Depois de salvar, rode flutter pub get no terminal.

Arquivo: lib/main.dart (ATUALIZE)
Vamos "prover" nossos serviços para todo o aplicativo.

Dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Instanciamos nossos serviços uma única vez.
  final hiveService = HiveService();
  await hiveService.init();
  final llmService = LLMService();

  runApp(
    // O MultiProvider torna os serviços disponíveis para todos os widgets filhos.
    MultiProvider(
      providers: [
        Provider<HiveService>.value(value: hiveService),
        Provider<LLMService>.value(value: llmService),
        // Se tivéssemos mais serviços (FoodApiService), adicionaríamos aqui.
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inicializamos o LLMService aqui, após o perfil do usuário ser carregado.
    // Isso garante que a chave de API correta seja usada.
    final userProfile = context.read<HiveService>().getUserProfile();
    context.read<LLMService>().initialize(userProfile);
    
    return MaterialApp(
      title: 'Fitness AI',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}
2. Integrando Dados Reais nas Telas
Agora que o Provider está configurado, vamos usá-lo para conectar nossas telas ao HiveService.

Arquivo: lib/features/2_profile/presentation/pages/profile_screen.dart (ATUALIZE)
Removemos a criação manual do HiveService e usamos o Provider.

Dart

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
  // Não precisamos mais instanciar o serviço aqui!

  late UserProfile _userProfile;
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _geminiApiKeyController;
  late TextEditingController _gptApiKeyController;

  String _selectedLlmProvider = 'gemini';

  @override
  void initState() {
    super.initState();
    // Acessamos o serviço via context.
    // `read` é usado dentro de initState e funções.
    _userProfile = context.read<HiveService>().getUserProfile();

    _nameController = TextEditingController(text: _userProfile.name);
    _heightController = TextEditingController(text: _userProfile.height?.toString());
    _weightController = TextEditingController(text: _userProfile.weight?.toString());
    _geminiApiKeyController = TextEditingController(text: _userProfile.geminiApiKey);
    _gptApiKeyController = TextEditingController(text: _userProfile.gptApiKey);
    _selectedLlmProvider = _userProfile.selectedLlm;
  }
  
  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final updatedProfile = UserProfile(
        name: _nameController.text,
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        geminiApiKey: _geminiApiKeyController.text,
        gptApiKey: _gptApiKeyController.text,
        selectedLlm: _selectedLlmProvider,
        birthDate: _userProfile.birthDate,
        gender: _userProfile.gender,
        bodyFatPercentage: _userProfile.bodyFatPercentage,
      );

      // Usamos o serviço do Provider para salvar
      final hiveService = context.read<HiveService>();
      hiveService.saveUserProfile(updatedProfile);
      
      // Re-inicializamos o LLMService com a nova chave/provedor
      context.read<LLMService>().initialize(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil salvo com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informações Pessoais', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(labelText: 'Altura (cm)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                keyboardType: TextInputType.number,
              ),
              // Adicione outros campos como data de nascimento, sexo, etc. aqui

              const SizedBox(height: 32),
              Text('Configurações da IA', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLlmProvider,
                decoration: const InputDecoration(labelText: 'Provedor de IA'),
                items: const [
                  DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                  DropdownMenuItem(value: 'gpt', child: Text('OpenAI GPT')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLlmProvider = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _geminiApiKeyController,
                decoration: const InputDecoration(labelText: 'Chave de API do Gemini'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gptApiKeyController,
                decoration: const InputDecoration(labelText: 'Chave de API do OpenAI (GPT)'),
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
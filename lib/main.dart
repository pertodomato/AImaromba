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
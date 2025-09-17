import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seu_app/core/services/hive_service.dart';
import 'package:seu_app/core/services/llm_service.dart';
import 'package:seu_app/core/services/food_repository.dart';
import 'package:seu_app/core/services/theme_service.dart';
import 'package:seu_app/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hiveService = HiveService();
  await hiveService.init();

  final llmService = LLMService();

  final foodRepo = FoodRepository();
  await foodRepo.loadTaco();

  final themeService = ThemeService();
  await themeService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<HiveService>.value(value: hiveService),
        Provider<LLMService>.value(value: llmService),
        Provider<FoodRepository>.value(value: foodRepo),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfile = context.read<HiveService>().getUserProfile();
    context.read<LLMService>().initialize(userProfile);
    final theme = context.watch<ThemeService>();

    return MaterialApp(
      title: 'Fitness AI',
      themeMode: theme.themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark().copyWith(
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

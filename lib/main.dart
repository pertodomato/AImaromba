// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitapp/presentation/providers/repository_providers.dart';
import 'router.dart';

// Provider para o estado de inicialização
final initializationProvider = FutureProvider<void>((ref) async {
  final profileRepo = ref.read(profileRepositoryProvider);
  final isFirstRun = await profileRepo.isFirstRun();
  if (isFirstRun) {
    await profileRepo.seedInitialData();
  }
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // O Hive será removido completamente na próxima fase.
  // Por enquanto, o código antigo que depende dele pode precisar que ele
  // seja inicializado, mas a nova lógica não o usará.

  runApp(const ProviderScope(child: AppLoading()));
}

class AppLoading extends ConsumerWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Assiste ao provider de inicialização. Enquanto ele está carregando,
    // mostramos uma tela de splash. Quando termina, mostramos o app.
    final init = ref.watch(initializationProvider);

    return init.when(
      data: (_) => const FitApp(),
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Erro ao inicializar o app: $err'))),
      ),
    );
  }
}


class FitApp extends ConsumerWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C2C2C),
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        elevation: 2,
        color: Color(0xFF2C2C2C),
      ),
    );

    return MaterialApp.router(
      title: 'FitApp',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
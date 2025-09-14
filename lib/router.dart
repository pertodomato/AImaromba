// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitapp/presentation/providers/repository_providers.dart';

// Core
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
// ... outros imports de tela

// Provider para o roteador, para que ele possa ler outros providers
final routerProvider = Provider<GoRouter>((ref) {
  
  // A lógica de redirecionamento agora pode acessar os repositórios
  String? redirectLogic(BuildContext context, GoRouterState state) {
    final profileRepo = ref.read(profileRepositoryProvider);
    // final workoutRepo = ref.read(workoutRepositoryProvider);
    
    // NOTA: isFirstRun agora é assíncrono. O ideal é que o `initializationProvider`
    // já tenha resolvido isso. No momento do roteamento, podemos assumir que
    // o DB já está populado se necessário.
    
    // Lógica futura para redirecionamento de treino ativo
    // final hasActiveWorkout = workoutRepo.hasActiveWorkoutStream.value;
    // if (hasActiveWorkout) return '/workout/active';
    
    return null; // Sem redirecionamento por enquanto
  }

  return GoRouter(
    initialLocation: '/dashboard', // Simplificado por agora
    // redirect: redirectLogic, // Habilitar quando os repositórios estiverem completos
    routes: [
       GoRoute(
        path: '/',
        redirect: (ctx, st) {
          // A verificação de firstRun é agora gerenciada pelo `initializationProvider`.
          // O app não chegará aqui na primeira execução até que o `seed` termine.
          // Portanto, podemos sempre redirecionar para o dashboard.
          // A lógica de onboarding pode ser um estado dentro do app em vez de um redirect.
          return '/dashboard';
        },
      ),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      // ... outras rotas
    ],
  );
});

// Modifique o MaterialApp para usar o routerProvider
// Em FitApp:
// final router = ref.watch(routerProvider);
// return MaterialApp.router(routerConfig: router, ...);
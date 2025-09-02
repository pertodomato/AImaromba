import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/muscle_screen.dart';
import 'screens/library_screen.dart';
import 'screens/train_sessions_screen.dart'; // << novo nome
import 'screens/planner_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (ctx, st) {
        final firstRun = Hive.box('settings').get('firstRun', defaultValue: false);
        return firstRun ? '/onboarding' : '/dashboard';
      },
    ),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
    GoRoute(path: '/muscle', builder: (c, s) => const MuscleScreen()),
    GoRoute(path: '/library', builder: (c, s) => const LibraryScreen()),
    GoRoute(path: '/criar_treinos', builder: (c, s) => const TrainSessionsScreen()), // << sessão
    GoRoute(path: '/planner', builder: (c, s) => const PlannerScreen()),
    GoRoute(path: '/workout/:blockId', builder: (c, s) => WorkoutScreen(blockId: s.pathParameters['blockId']!)),
    GoRoute(path: '/nutrition', builder: (c, s) => const NutritionScreen()),
    GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
  ],
);

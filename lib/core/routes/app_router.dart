// ────────────────────────────────────────────────────────────────────────────
// core/routes/app_router.dart
// Centralized GoRouter — all routes, transitions, and guards in one place
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/home_shell.dart';
import '../../features/dashboard/presentation/scan_history_page.dart';
import '../../features/dashboard/presentation/service_logs_page.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';
import '../../features/inspection/presentation/inspection_checklist_screen.dart';
import '../../features/vehicles/presentation/vehicles_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../presentation/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => _fade(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      pageBuilder: (context, state) => _fade(state, const HomeShell()),
    ),
    GoRoute(
      path: '/scan-history',
      name: 'scan-history',
      pageBuilder: (context, state) =>
          _slide(state, const ScanHistoryPage()),
    ),
    GoRoute(
      path: '/service-logs',
      name: 'service-logs',
      pageBuilder: (context, state) =>
          _slide(state, const ServiceLogsPage()),
    ),
    GoRoute(
      path: '/chatbot',
      name: 'chatbot',
      pageBuilder: (context, state) =>
          _slide(state, const ChatbotScreen()),
    ),
    GoRoute(
      path: '/inspection',
      name: 'inspection',
      pageBuilder: (context, state) =>
          _slide(state, const InspectionChecklistScreen()),
    ),
    GoRoute(
      path: '/vehicles',
      name: 'vehicles',
      pageBuilder: (context, state) =>
          _slide(state, const VehiclesScreen()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          _slide(state, const SettingsScreen()),
    ),
  ],
);

// ── Page transition helpers ───────────────────────────────────────────────────

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

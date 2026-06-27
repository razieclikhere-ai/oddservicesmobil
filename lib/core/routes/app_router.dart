import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        name: 'vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/obd-scanner',
        name: 'obd-scanner',
        builder: (context, state) => const OBDScannerScreen(),
      ),
      GoRoute(
        path: '/ai-analyzer',
        name: 'ai-analyzer',
        builder: (context, state) => const AIAnalyzerScreen(),
      ),
      GoRoute(
        path: '/service-schedule',
        name: 'service-schedule',
        builder: (context, state) => const ServiceScheduleScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/chatbot',
        name: 'chatbot',
        builder: (context, state) => const ChatbotScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

final appRouter = appRouterProvider;

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Vehicles')), body: const Center(child: Text('Vehicles Screen')));
}
class OBDScannerScreen extends StatelessWidget {
  const OBDScannerScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('OBD Scanner')), body: const Center(child: Text('OBD Scanner Screen')));
}
class AIAnalyzerScreen extends StatelessWidget {
  const AIAnalyzerScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('AI Analyzer')), body: const Center(child: Text('AI Analyzer Screen')));
}
class ServiceScheduleScreen extends StatelessWidget {
  const ServiceScheduleScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Service Schedule')), body: const Center(child: Text('Service Schedule Screen')));
}
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reports')), body: const Center(child: Text('Reports Screen')));
}
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: const Center(child: Text('Settings Screen')));
}
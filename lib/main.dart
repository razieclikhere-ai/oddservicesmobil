import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/chatbot/presentation/chatbot_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartOBDApp()));
}

class SmartOBDApp extends StatelessWidget {
  const SmartOBDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart OBD Service Assistant',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/chatbot',
      name: 'chatbot',
      builder: (context, state) => const ChatbotScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      name: 'vehicles',
      builder: (context, state) => _PlaceholderScreen('Manajemen Kendaraan'),
    ),
    GoRoute(
      path: '/obd-scanner',
      name: 'obd-scanner',
      builder: (context, state) => _PlaceholderScreen('OBD Scanner'),
    ),
    GoRoute(
      path: '/ai-analyzer',
      name: 'ai-analyzer',
      builder: (context, state) => _PlaceholderScreen('AI Analyzer'),
    ),
    GoRoute(
      path: '/service-schedule',
      name: 'service-schedule',
      builder: (context, state) => _PlaceholderScreen('Jadwal Servis'),
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => _PlaceholderScreen('Laporan PDF'),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => _PlaceholderScreen('Pengaturan'),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded, size: 64, color: AppTheme.neonCyan),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sedang dalam pengembangan', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
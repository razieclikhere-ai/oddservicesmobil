import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/chatbot/presentation/chatbot_screen.dart';
import 'features/inspection/presentation/inspection_checklist_screen.dart';
import 'features/vehicles/presentation/vehicles_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/obd_bluetooth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full screen immersive
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBg,
  ));

  await NotificationService.init();
  ObdBluetoothService.instance.connectToObd();

  runApp(const ProviderScope(child: SmartOBDApp()));
}


class SmartOBDApp extends StatelessWidget {
  const SmartOBDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chek Mobilku',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'features/dashboard/presentation/scan_history_page.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const HomeShell(),
    ),
    GoRoute(
      path: '/scan-history',
      name: 'scan-history',
      builder: (context, state) => const ScanHistoryPage(),
    ),
    GoRoute(
      path: '/chatbot',
      name: 'chatbot',
      builder: (context, state) => const ChatbotScreen(),
    ),
    GoRoute(
      path: '/inspection',
      name: 'inspection',
      builder: (context, state) => const InspectionChecklistScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      name: 'vehicles',
      builder: (context, state) => const VehiclesScreen(),
    ),
    GoRoute(
      path: '/obd-scanner',
      name: 'obd-scanner',
      builder: (context, state) => const _PlaceholderScreen('OBD Scanner'),
    ),
    GoRoute(
      path: '/ai-analyzer',
      name: 'ai-analyzer',
      builder: (context, state) => const _PlaceholderScreen('AI Analyzer'),
    ),
    GoRoute(
      path: '/service-schedule',
      name: 'service-schedule',
      builder: (context, state) => const _PlaceholderScreen('Jadwal Servis'),
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const _PlaceholderScreen('Laporan PDF'),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const _PlaceholderScreen('Pengaturan'),
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

// ─── Splash Screen ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Background subtle circuit pattern via gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF0F1A2B), AppTheme.darkBg],
              ),
            ),
          ),
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo image
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 140,
                  height: 140,
                  errorBuilder: (_, __, ___) => Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonCyan, width: 2),
                    ),
                    child: const Icon(Icons.speed, color: AppTheme.neonCyan, size: 60),
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.6, 0.6), duration: 600.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 28),
                // App name
                const Text(
                  'CHEK MOBILKU',
                  style: TextStyle(
                    color: AppTheme.neonCyan,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 8),
                const Text(
                  'AI Vehicle Intelligence',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 500.ms),
                const SizedBox(height: 60),
                // Loading dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.neonCyan,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 0.4,
                          end: 1.2,
                          delay: Duration(milliseconds: i * 200),
                          duration: 500.ms,
                          curve: Curves.easeInOut,
                        );
                  }),
                ),
              ],
            ),
          ),
          // Version watermark
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: const Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ).animate().fadeIn(delay: 700.ms),
          ),
        ],
      ),
    );
  }
}
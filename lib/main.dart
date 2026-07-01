// ────────────────────────────────────────────────────────────────────────────
// main.dart — Clean entry point
// Router delegated to core/routes/app_router.dart
// SplashScreen in core/presentation/splash_screen.dart
// HomeShell in features/dashboard/presentation/home_shell.dart
// Trigger build: 2026-06-30 UI/UX and AI Bugfix deployment
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/obd_bluetooth_service.dart';
import 'core/routes/app_router.dart';
import 'core/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error widget for easier debugging in release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bug_report_rounded, color: Colors.redAccent, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Oops! Terjadi Gangguan Sistem',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        '${details.exception}\n\n${details.stack}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Harap tangkap layar (screenshot) halaman ini dan kirimkan ke chat agar dapat langsung saya perbaiki.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // System UI — full dark immersive
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBg,
  ));

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init locale for date formatting (Indonesian)
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Bootstrap: Locale initialization failed: $e');
  }

  // Init notification service
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Bootstrap: NotificationService initialization failed: $e');
  }

  runApp(const ProviderScope(child: SmartOBDApp()));
}

class SmartOBDApp extends ConsumerWidget {
  const SmartOBDApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bootstrap: load active vehicle and OBD last data on startup
    ref.listen(activeVehicleProvider, (prev, next) {
      next.whenData((uuid) {
        ObdBluetoothService.instance.loadLastSavedData(uuid);
      });
    });

    final mode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Chek Mobilku',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Animate effects globally
        Animate.restartOnHotReload = true;
        return child!;
      },
    );
  }
}
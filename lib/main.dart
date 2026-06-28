// ────────────────────────────────────────────────────────────────────────────
// main.dart — Clean entry point
// Router delegated to core/routes/app_router.dart
// SplashScreen in core/presentation/splash_screen.dart
// HomeShell in features/dashboard/presentation/home_shell.dart
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
  await initializeDateFormatting('id_ID', null);

  // Init notification service
  await NotificationService.init();

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

    return MaterialApp.router(
      title: 'Chek Mobilku',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
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
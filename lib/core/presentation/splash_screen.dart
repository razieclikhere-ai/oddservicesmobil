// ────────────────────────────────────────────────────────────────────────────
// core/presentation/splash_screen.dart
// Extracted from main.dart — standalone animated splash
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool('has_seen_permissions') ?? false;
        if (seen) {
          context.go('/dashboard');
        } else {
          context.go('/permissions');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Background radial gradient
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
                // Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.neonCyan.withOpacity(0.08), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonCyan.withOpacity(0.1),
                        blurRadius: 32,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/splash_logo.png',
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
                      child: const Icon(Icons.speed,
                          color: AppTheme.neonCyan, size: 60),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                        begin: const Offset(0.7, 0.7),
                        duration: 800.ms,
                        curve: Curves.elasticOut)
                    .then()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.05, 1.05),
                        duration: 1500.ms,
                        curve: Curves.easeInOut),

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
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

                const SizedBox(height: 60),

                // Animated loading dots
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

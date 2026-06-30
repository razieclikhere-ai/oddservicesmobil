// ────────────────────────────────────────────────────────────────────────────
// core/presentation/splash_screen.dart
// Extracted from main.dart — standalone animated splash
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
                Image.asset(
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
                )
                    .animate()
                    .scale(
                        begin: const Offset(0.6, 0.6),
                        duration: 600.ms,
                        curve: Curves.elasticOut)
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

// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/home_shell.dart
// Main scaffold with bottom nav + floating Jazzy AI button
// Extracted from dashboard_screen.dart (was HomeShell class)
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'dashboard_screen.dart';
import 'schedule_page.dart';
import 'voice_chat_screen.dart';
import '../../vehicles/presentation/vehicles_screen.dart';
import 'profile_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _pages = [
    DashboardScreen(),
    SchedulePage(),
    VoiceChatScreen(),
    VehiclesScreen(),
    ProfilePage(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.build_circle_rounded, label: 'Service'),
    _NavItem(icon: Icons.mic_rounded, label: 'Voice Chat'),
    _NavItem(icon: Icons.directions_car_rounded, label: 'Kendaraan'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(dashboardTabIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey[100],
      body: IndexedStack(index: navIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: navIndex,
        items: _navItems,
        onTap: (i) => ref.read(dashboardTabIndexProvider.notifier).state = i,
      ),
    );
  }
}

// ── Nav item data model ───────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── Bottom navigation bar widget ──────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withOpacity(0.92) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), 
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isActive = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: (MediaQuery.of(context).size.width - 64) / items.length - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        transform: isActive
                            ? (Matrix4.identity()..translate(0, -3))
                            : Matrix4.identity(),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isActive
                              ? AppTheme.neonCyan
                              : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: isActive ? 18 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan,
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonCyan.withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

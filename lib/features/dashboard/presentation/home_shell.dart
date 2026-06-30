// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/home_shell.dart
// Main scaffold with bottom nav + floating Jazzy AI button
// Extracted from dashboard_screen.dart (was HomeShell class)
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'dashboard_screen.dart';
import 'obd_live_page.dart';
import 'schedule_page.dart';
import 'profile_page.dart';
import 'widgets/jazzy_voice_assistant.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _pages = [
    DashboardScreen(),
    ObdLivePage(),
    SchedulePage(),
    ProfilePage(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.sensors, label: 'Live OBD'),
    _NavItem(icon: Icons.build_circle_rounded, label: 'Servis'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(dashboardTabIndexProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          IndexedStack(index: navIndex, children: _pages),
          const Positioned(
            bottom: 16,
            right: 16,
            child: JazzyVoiceAssistant(),
          ),
        ],
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                  width: MediaQuery.of(context).size.width / items.length - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: isActive
                            ? (Matrix4.identity()..translate(0, -2))
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
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 16 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan,
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonCyan.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 0.5,
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
                              ? Colors.white
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

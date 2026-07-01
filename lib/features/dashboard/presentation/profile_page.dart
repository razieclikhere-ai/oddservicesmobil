// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/profile_page.dart
// Profil tab — navigation menu, vehicle info, about app
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/obd_bluetooth_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final activeUuid = ref.watch(activeVehicleUuidProvider);
    final connectionState = ref.watch(obdConnectionStateProvider);
    final obdState =
        connectionState.valueOrNull ?? ObdConnectionState.disconnected;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Profil & Pengaturan',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () => context.push('/settings'),
            tooltip: 'Pengaturan',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active vehicle card
          vehiclesAsync.when(
            loading: () => _VehicleCard(
              name: 'Memuat...',
              brand: '',
              mileage: 0,
              activeUuid: activeUuid,
              uuid: '',
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (vehicles) {
              final active = vehicles.firstWhere(
                (v) => v['uuid'] == activeUuid,
                orElse: () => vehicles.isEmpty
                    ? <String, dynamic>{}
                    : vehicles.first,
              );
              if (active.isEmpty) return const SizedBox.shrink();
              return _VehicleCard(
                name: active['name'] as String? ?? '-',
                brand:
                    '${active['brand']} ${active['model']} ${active['year']}',
                mileage: active['current_mileage'] as int? ?? 0,
                uuid: active['uuid'] as String? ?? '',
                activeUuid: activeUuid,
              );
            },
          ),
          const SizedBox(height: 20),

          // Connectivity section
          _SectionLabel('Koneksi'),
          _MenuCard(
            icon: Icons.bluetooth_searching,
            title: obdState == ObdConnectionState.connected
                ? 'OBD Terhubung — Ketuk untuk Putus'
                : obdState == ObdConnectionState.scanning
                    ? 'Scanning OBD...'
                    : 'Hubungkan Bluetooth OBD',
            subtitle: 'Adaptor ELM327 / Bluetooth Classic SPP',
            color: obdState == ObdConnectionState.connected
                ? AppTheme.neonGreen
                : Colors.blueAccent,
            onTap: () {
              if (obdState == ObdConnectionState.disconnected) {
                ObdBluetoothService.instance.connectToObd();
              } else {
                ObdBluetoothService.instance.disconnect();
              }
            },
          ),
          const SizedBox(height: 8),

          // Features section
          _SectionLabel('Fitur'),
          _MenuCard(
            icon: Icons.directions_car_rounded,
            title: 'Manajemen Kendaraan',
            subtitle: 'Tambah/kelola data kendaraan Anda',
            color: AppTheme.neonCyan,
            onTap: () => context.push('/vehicles'),
          ),
          const SizedBox(height: 8),
          _MenuCard(
            icon: Icons.checklist_rounded,
            title: 'Inspeksi Kendaraan',
            subtitle: '23 poin pemeriksaan dianalisis AI',
            color: AppTheme.neonGreen,
            onTap: () => context.push('/inspection'),
          ),
          const SizedBox(height: 8),
          _MenuCard(
            icon: Icons.library_books_rounded,
            title: 'Catatan & Riwayat Servis',
            subtitle: 'Catat ganti oli, aki, rem + Analisis AI',
            color: AppTheme.neonCyan,
            onTap: () => context.push('/service-logs'),
          ),
          const SizedBox(height: 8),
          _MenuCard(
            icon: FontAwesomeIcons.robot,
            title: 'AI Chatbot Mekanik',
            subtitle: 'Tanya AI soal masalah kendaraan',
            color: AppTheme.neonOrange,
            onTap: () => context.push('/chatbot'),
          ),
          const SizedBox(height: 8),
          _MenuCard(
            icon: Icons.history_rounded,
            title: 'Riwayat Scan OBD',
            subtitle: 'Lihat log data sensor historis',
            color: Colors.purpleAccent,
            onTap: () => context.push('/scan-history'),
          ),
          const SizedBox(height: 20),

          // About card
          _SectionLabel('Tentang'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.neonCyan, width: 1)),
                      child: const Icon(Icons.speed,
                          color: AppTheme.neonCyan, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chek Mobilku',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text('AI Vehicle Intelligence v1.0.0',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  )
                ]),
                const SizedBox(height: 12),
                Divider(
                    color: Colors.white.withOpacity(0.06)),
                const SizedBox(height: 8),
                Text(
                  'Powered by Groq · Llama 3 70B\nOBD-II Bluetooth Classic · ELM327 Protocol',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String name, brand, uuid, activeUuid;
  final int mileage;
  const _VehicleCard({
    required this.name,
    required this.brand,
    required this.mileage,
    required this.uuid,
    required this.activeUuid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.neonCyan.withOpacity(0.08),
            AppTheme.darkSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.neonCyan.withOpacity(0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonCyan.withOpacity(0.02),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.neonCyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.15)),
          ),
          child: const Icon(Icons.directions_car,
              color: AppTheme.neonCyan, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(brand,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.speed, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('$mileage km',
                    style: const TextStyle(
                        color: AppTheme.neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.neonGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.neonGreen.withOpacity(0.2)),
          ),
          child: const Text('AKTIF',
              style: TextStyle(
                  color: AppTheme.neonGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.darkSurface,
      borderRadius: AppTheme.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppTheme.cardRadius,
            border: AppTheme.glassBorder,
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withOpacity(0.12)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.grey[600], size: 20),
          ]),
        ),
      ),
    );
  }
}

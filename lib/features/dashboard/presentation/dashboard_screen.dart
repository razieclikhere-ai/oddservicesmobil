// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/dashboard_screen.dart
// Main dashboard tab — slimmed down, uses Riverpod providers
// HomeShell → home_shell.dart | OBD Live → obd_live_page.dart
// Schedule → schedule_page.dart | Profile → profile_page.dart
// ────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/obd_bluetooth_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StreamSubscription<ObdConnectionState>? _stateSub;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();

    // Reload DB data when OBD state changes
    _stateSub =
        ObdBluetoothService.instance.connectionStateStream.listen((_) {
      if (mounted) {
        ref.invalidate(schedulesProvider);
        ref.invalidate(recentScansProvider);
      }
    });

    // Refresh UI every 2 s while screen is open (live sensor updates)
    _uiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ObdBluetoothService.instance.loadLastSavedData();
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obd = ObdBluetoothService.instance;
    final state = obd.currentState;
    final schedulesAsync = ref.watch(schedulesProvider);
    final recentScansAsync = ref.watch(recentScansProvider);
    final serviceLogsAsync = ref.watch(serviceLogsProvider);
    final activeUuid = ref.watch(activeVehicleUuidProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final inspectionProblems = ref.watch(inspectionProblemsCountProvider).valueOrNull ?? 0;
    final health = _calcHealthScore(obd, inspectionProblems);
    final size = MediaQuery.of(context).size;

    // Get active vehicle name dynamically
    final activeVehicle = vehiclesAsync.valueOrNull?.firstWhere(
      (v) => v['uuid'] == activeUuid,
      orElse: () => <String, dynamic>{},
    );
    final vehicleName = (activeVehicle != null && activeVehicle.isNotEmpty)
        ? activeVehicle['name'] as String? ?? 'Kendaraan Saya'
        : 'Kendaraan Saya';

    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(state),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width > 600 ? 32 : 16,
              vertical: 8,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Connection banner
                _ConnectionBanner(
                    state: state, onTap: _toggleConnection),
                const SizedBox(height: 16),

                // Real-time speed & RPM gauges
                Row(children: [
                  Expanded(
                    child: _CircularGauge(
                      label: 'Kecepatan',
                      value: obd.speed.toStringAsFixed(0),
                      unit: 'km/h',
                      max: 200,
                      current: obd.speed,
                      color: AppTheme.neonCyan,
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CircularGauge(
                      label: 'RPM Mesin',
                      value: obd.rpm.toStringAsFixed(0),
                      unit: 'rpm',
                      max: 7000,
                      current: obd.rpm,
                      color: AppTheme.neonOrange,
                      icon: Icons.rotate_right,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // Health ring
                _HealthRingCard(
                  score: health,
                  odometer: obd.currentOdometer,
                  vehicleName: vehicleName,
                  onTap: () => _showHealthReportDialog(
                      context, obd, inspectionProblems, schedulesAsync.valueOrNull ?? []),
                ),
                const SizedBox(height: 20),

                // Diagnostic Quick Panel
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'Status Diagnostik AI',
                    ),
                    const SizedBox(height: 10),
                    _DiagnosticStatusPanel(
                      obd: obd,
                      inspectionProblems: inspectionProblems,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Upcoming service
                GestureDetector(
                  onTap: () => ref.read(dashboardTabIndexProvider.notifier).state = 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(title: 'Jadwal Servis Berikutnya (Prediksi AI)'),
                      const SizedBox(height: 10),
                      schedulesAsync.when(
                        loading: () => const SizedBox(
                            height: 80,
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.neonCyan,
                                    strokeWidth: 2))),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (schedules) => _UpcomingServiceCard(
                            schedules: schedules,
                            odometer: obd.currentOdometer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Recent Service Logs
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Catatan Servis Terakhir',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => context.push('/service-logs'),
                          child: const Text('Lihat Semua',
                              style: TextStyle(
                                  color: AppTheme.neonCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    serviceLogsAsync.when(
                      loading: () => const SizedBox(
                          height: 80,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.neonCyan,
                                  strokeWidth: 2))),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (logs) => _RecentServiceLogsDashboardList(logs: logs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick actions
                _SectionHeader(title: 'Aksi Cepat'),
                const SizedBox(height: 10),
                _QuickActionsRow(),
                const SizedBox(height: 20),

                // Recent scan history
                recentScansAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (scans) {
                    if (scans.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Riwayat Scan Terakhir',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () =>
                                  context.push('/scan-history'),
                              child: const Text('Lihat Semua',
                                  style: TextStyle(
                                      color: AppTheme.neonCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _RecentScansTable(scans: scans),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  int _calcHealthScore(ObdBluetoothService obd, int inspectionProblems) {
    int score = 100;
    if (obd.batteryVoltage > 0) {
      if (obd.batteryVoltage < 12.0) score -= 25;
      else if (obd.batteryVoltage < 12.5) score -= 10;
    }
    if (obd.coolantTemp > 0) {
      if (obd.coolantTemp > 105) score -= 20;
      else if (obd.coolantTemp > 100) score -= 8;
    }
    if (obd.fuelTrim.abs() > 10) score -= 10;
    if (obd.dtcCodes.isNotEmpty) score -= 15;
    score -= (inspectionProblems * 10);
    return score.clamp(0, 100);
  }

  void _showHealthReportDialog(BuildContext context, ObdBluetoothService obd,
      int inspectionProblems, List<Map<String, dynamic>> schedules) {
    final health = _calcHealthScore(obd, inspectionProblems);
    final recommendations = <Map<String, String>>[];

    if (obd.dtcCodes.isNotEmpty) {
      recommendations.add({
        'title': 'DTC Error Terdeteksi (${obd.dtcCodes})',
        'desc': 'Terdeteksi kode error malfungsi pada komputer mesin. Lakukan diagnosa dan reset DTC setelah perbaikan sensor.',
        'action': 'Gunakan AI Chatbot untuk analisis detail DTC ini.',
      });
    }

    if (obd.batteryVoltage > 0 && obd.batteryVoltage < 12.5) {
      final isWeak = obd.batteryVoltage < 12.0;
      recommendations.add({
        'title': isWeak ? 'Tegangan Aki Lemah (${obd.batteryVoltage.toStringAsFixed(2)}V)' : 'Tegangan Aki Menurun (${obd.batteryVoltage.toStringAsFixed(2)}V)',
        'desc': isWeak
            ? 'Tegangan aki berada di bawah ambang batas aman. Segera cas ulang aki atau ganti baru untuk menghindari mogok.'
            : 'Tegangan aki sedikit turun. Periksa koneksi terminal aki dari kerak atau korosi.',
        'action': 'Periksa kelistrikan aki dan alternator.',
      });
    }

    if (obd.coolantTemp > 0 && obd.coolantTemp > 100) {
      final isOverheat = obd.coolantTemp > 105;
      recommendations.add({
        'title': isOverheat ? 'Radiator Overheat (${obd.coolantTemp.toStringAsFixed(1)}°C)' : 'Suhu Radiator Tinggi (${obd.coolantTemp.toStringAsFixed(1)}°C)',
        'desc': isOverheat
            ? 'Suhu radiator kritis! Parkir mobil segera, biarkan mesin dingin, lalu periksa kebocoran coolant atau kegagalan kipas radiator.'
            : 'Suhu pendingin mesin tinggi. Periksa volume air coolant di tabung reservoir.',
        'action': 'Periksa air radiator dan thermostat.',
      });
    }

    if (obd.fuelTrim.abs() > 10) {
      recommendations.add({
        'title': 'Penyimpangan Campuran Bahan Bakar (${obd.fuelTrim.toStringAsFixed(2)}%)',
        'desc': 'Campuran bensin dan udara terlalu kaya atau terlalu miskin. Periksa sensor O2 atau kebocoran vakum udara.',
        'action': 'Periksa filter udara dan kebocoran selang vakum.',
      });
    }

    if (inspectionProblems > 0) {
      recommendations.add({
        'title': 'Masalah Inspeksi Fisik ($inspectionProblems Masalah)',
        'desc': 'Terdapat beberapa item bermasalah pada hasil cek fisik ban/kebocoran/rem di tab Inspeksi.',
        'action': 'Buka menu Inspeksi Fisik untuk melihat daftar checklist.',
      });
    }

    final overdueSchedules = schedules.where((s) {
      final dateStr = s['next_predicted_date'] as String? ?? '';
      final date = DateTime.tryParse(dateStr);
      return date != null && date.isBefore(DateTime.now());
    }).toList();

    if (overdueSchedules.isNotEmpty) {
      recommendations.add({
        'title': 'Jadwal Servis Terlambat (${overdueSchedules.length} Servis)',
        'desc': 'Ada jadwal servis berkala yang sudah melewati target tanggal atau kilometer.',
        'action': 'Catat servis baru di menu Catatan Servis.',
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rencana Pemulihan Kesehatan (100% Health)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Kondisi Saat Ini: $health/100',
                    style: TextStyle(
                        color: health >= 85
                            ? AppTheme.neonGreen
                            : health >= 65
                                ? AppTheme.neonYellow
                                : AppTheme.neonOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  const Text('Daftar Rekomendasi Perbaikan',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              Expanded(
                child: recommendations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user_rounded,
                                size: 56, color: AppTheme.neonGreen),
                            const SizedBox(height: 12),
                            const Text(
                              'Mobil Anda 100% Sehat!',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Semua sensor OBD normal, tidak ada DTC, dan inspeksi fisik bersih.',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: recommendations.length,
                        itemBuilder: (ctx, idx) {
                          final rec = recommendations[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.neonOrange.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: AppTheme.neonOrange, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rec['title']!,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rec['desc']!,
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      height: 1.4),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.neonCyan.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.build_rounded,
                                          color: AppTheme.neonCyan, size: 13),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Tindakan: ${rec['action']}',
                                          style: const TextStyle(
                                              color: AppTheme.neonCyan,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(ObdConnectionState state) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      snap: true,
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey[50],
      title: Row(children: [
        Image.asset(
          'assets/images/app_icon.png',
          width: 28,
          height: 28,
          errorBuilder: (_, __, ___) => const Icon(
              Icons.speed,
              color: AppTheme.neonCyan,
              size: 24),
        ),
        const SizedBox(width: 10),
        Text(
          'CHEK MOBILKU',
          style: TextStyle(
              color: isDark ? AppTheme.neonCyan : Colors.blue[900],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2),
        ),
      ]),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? Colors.grey : Colors.black87,
            size: 20,
          ),
          onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          tooltip: 'Ganti Tema',
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.robot,
              color: AppTheme.neonCyan, size: 18),
          onPressed: () => context.push('/chatbot'),
          tooltip: 'AI Chatbot',
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined,
              color: isDark ? Colors.grey : Colors.black87, size: 20),
          onPressed: () => context.push('/settings'),
          tooltip: 'Pengaturan',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _toggleConnection() {
    final s = ObdBluetoothService.instance.currentState;
    if (s == ObdConnectionState.disconnected) {
      ObdBluetoothService.instance.connectToObd();
    } else if (s == ObdConnectionState.connected ||
        s == ObdConnectionState.simulating) {
      ObdBluetoothService.instance.disconnect();
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  final ObdConnectionState state;
  final VoidCallback onTap;
  const _ConnectionBanner(
      {required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(state);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (cfg['color'] as Color).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: (cfg['color'] as Color).withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: cfg['color'] as Color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg['title'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(cfg['subtitle'] as String,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ),
          Icon(cfg['trailing'] as IconData,
              color: cfg['color'] as Color, size: 18),
        ]),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Map<String, dynamic> _config(ObdConnectionState s) {
    switch (s) {
      case ObdConnectionState.connected:
        return {
          'color': AppTheme.neonGreen,
          'title': 'OBD-II Bluetooth Terhubung',
          'subtitle': 'Menerima data sensor secara real-time',
          'trailing': Icons.bluetooth_connected,
        };
      case ObdConnectionState.simulating:
        return {
          'color': AppTheme.neonYellow,
          'title': 'Mode Simulasi Aktif',
          'subtitle': 'Ketuk untuk mencoba koneksi Bluetooth nyata',
          'trailing': Icons.bolt,
        };
      case ObdConnectionState.scanning:
        return {
          'color': AppTheme.neonCyan,
          'title': 'Memindai Perangkat Bluetooth...',
          'subtitle': 'Menunggu adaptor ELM327 di dekat Anda',
          'trailing': Icons.bluetooth_searching,
        };
      case ObdConnectionState.connecting:
        return {
          'color': AppTheme.neonCyan,
          'title': 'Menghubungkan ke Adaptor...',
          'subtitle': 'Mohon tunggu sebentar',
          'trailing': Icons.bluetooth_searching,
        };
      default:
        return {
          'color': Colors.grey,
          'title': 'Adaptor OBD Belum Terhubung',
          'subtitle': 'Ketuk untuk memulai scanning Bluetooth',
          'trailing': Icons.bluetooth_disabled,
        };
    }
  }
}

class _HealthRingCard extends StatelessWidget {
    final int score;
    final int odometer;
    final String vehicleName;
    final VoidCallback? onTap;
    const _HealthRingCard(
        {required this.score,
        required this.odometer,
        required this.vehicleName,
        this.onTap});

    @override
    Widget build(BuildContext context) {
      final color = score >= 85
          ? AppTheme.neonGreen
          : score >= 65
              ? AppTheme.neonYellow
              : AppTheme.neonOrange;
      final label = score >= 85
          ? 'Kondisi Prima'
          : score >= 65
              ? 'Perlu Perhatian'
              : 'Segera Servis';

      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 4)
            ],
          ),
          child: Row(children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(alignment: Alignment.center, children: [
                // Glow Halo
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 14,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.18)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Main Ring
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$score',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  Text('/ 100',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                ]),
              ]),
            ).animate().scale(
                delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Kesehatan Kendaraan',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(vehicleName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.speed, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('$odometer km',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Ketuk untuk rencana pemulihan 100%',
                      style: TextStyle(color: Colors.white24, fontSize: 9)),
                ],
              ),
            ),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
    }
  }

class _DiagnosticStatusPanel extends StatelessWidget {
  final ObdBluetoothService obd;
  final int inspectionProblems;
  const _DiagnosticStatusPanel({required this.obd, required this.inspectionProblems});

  @override
  Widget build(BuildContext context) {
    // Battery Status
    final batteryColor = obd.batteryVoltage == 0
        ? Colors.grey
        : obd.batteryVoltage < 12.0
            ? AppTheme.neonOrange
            : obd.batteryVoltage < 12.5
                ? AppTheme.neonYellow
                : AppTheme.neonGreen;
    final batteryText = obd.batteryVoltage == 0 ? '-' : '${obd.batteryVoltage.toStringAsFixed(1)}V';

    // Coolant Status
    final coolantColor = obd.coolantTemp == 0
        ? Colors.grey
        : obd.coolantTemp > 105
            ? AppTheme.neonOrange
            : obd.coolantTemp > 100
                ? AppTheme.neonYellow
                : AppTheme.neonGreen;
    final coolantText = obd.coolantTemp == 0 ? '-' : '${obd.coolantTemp.toStringAsFixed(0)}°C';

    // DTC Status
    final dtcColor = obd.dtcCodes.isEmpty ? AppTheme.neonGreen : AppTheme.neonOrange;
    final dtcText = obd.dtcCodes.isEmpty ? 'Sehat' : '${obd.dtcCodes.split(',').length} Kode';

    // Physical Status
    final physicalColor = inspectionProblems == 0 ? AppTheme.neonGreen : AppTheme.neonOrange;
    final physicalText = inspectionProblems == 0 ? 'Bagus' : '$inspectionProblems Eror';

    final items = [
      ('Aki', batteryText, batteryColor, FontAwesomeIcons.carBattery),
      ('Suhu', coolantText, coolantColor, Icons.thermostat),
      ('DTC', dtcText, dtcColor, Icons.report_problem_rounded),
      ('Fisik', physicalText, physicalColor, Icons.checklist_rounded),
    ];

    return Row(
      children: items.map((item) {
        final (label, val, color, icon) = item;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  val,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentServiceLogsDashboardList extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _RecentServiceLogsDashboardList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Icon(Icons.library_books_outlined, size: 36, color: Colors.grey[600]),
            const SizedBox(height: 10),
            const Text(
              'Belum Ada Catatan Servis',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Catat servis pertama Anda untuk mengaktifkan riwayat AI.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final recentLogs = logs.take(3).toList();
    return Column(
      children: recentLogs.map((log) {
        final type = log['service_type'] ?? 'Servis';
        final odo = log['current_mileage'] ?? 0;
        final dateStr = log['service_date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        final dateFormatted = date != null
            ? '${date.day}/${date.month}/${date.year}'
            : '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.build_rounded, size: 14, color: AppTheme.neonCyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Odometer: $odo km · $dateFormatted',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonCyan.withOpacity(0.5),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.neonCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.neonCyan.withOpacity(0.3)),
            ),
            child: Text(trailing!,
                style: const TextStyle(
                    color: AppTheme.neonCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}

class _UpcomingServiceCard extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;
  final int odometer;
  const _UpcomingServiceCard(
      {required this.schedules, required this.odometer});

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Text(
            'Belum ada jadwal. Hubungkan OBD untuk AI analisis.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    final next = schedules.first; // Already ordered by date ASC from DB
    final name = next['service_name'] as String? ?? 'Servis Berkala';
    final desc = next['description'] as String? ?? '';
    final nextMil = next['next_predicted_mileage'] as int? ?? 0;
    final nextDate = DateTime.tryParse(
        next['next_predicted_date'] as String? ?? '');
    final daysLeft =
        nextDate?.difference(DateTime.now()).inDays;
    final milLeft = nextMil - odometer;
    final urgent =
        (daysLeft != null && daysLeft <= 14) || milLeft <= 1000;
    final color =
        urgent ? AppTheme.neonOrange : AppTheme.neonGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                urgent
                    ? Icons.warning_rounded
                    : Icons.check_circle_outline,
                color: color,
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc,
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _StatChip(
                Icons.calendar_today,
                daysLeft != null ? '$daysLeft hari lagi' : '-',
                color),
            const SizedBox(width: 8),
            _StatChip(
                Icons.speed,
                milLeft > 0 ? '+$milLeft km' : 'Sekarang!',
                color),
          ]),
          if (schedules.length > 1) ...[
            const SizedBox(height: 10),
            Text('+${schedules.length - 1} jadwal servis lainnya',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.checklist_rounded, 'Inspeksi', AppTheme.neonCyan, '/inspection'),
      (Icons.library_books_rounded, 'Catatan', AppTheme.neonYellow, '/service-logs'),
      (FontAwesomeIcons.robot, 'Tanya AI', AppTheme.neonOrange, '/chatbot'),
      (Icons.directions_car_rounded, 'Kendaraan', AppTheme.neonGreen, '/vehicles'),
    ];

    return Row(
      children: actions.asMap().entries.map((e) {
        final (icon, label, color, route) = e.value;
        final isLast = e.key == actions.length - 1;
        return Expanded(
          child: GestureDetector(
            onTap: () => context.push(route),
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.12), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.02),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentScansTable extends StatelessWidget {
  final List<Map<String, dynamic>> scans;
  const _RecentScansTable({required this.scans});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(children: const [
            _TH('Waktu', flex: 3),
            _TH('Coolant', flex: 2),
            _TH('Aki (V)', flex: 2),
            _TH('RPM', flex: 2),
          ]),
        ),
        ...scans.asMap().entries.map((e) {
          final scan = e.value;
          final isLast = e.key == scans.length - 1;
          final date = DateTime.tryParse(
              scan['scan_date'] as String? ?? '');
          final timeStr = date != null
              ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
              : '-';
          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      top: BorderSide(
                          color: Colors.white.withOpacity(0.04))),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              _TC(timeStr, flex: 3),
              _TC(
                  '${(scan['coolant_temp'] as num?)?.toStringAsFixed(1) ?? '-'}°C',
                  flex: 2),
              _TC(
                  '${(scan['battery_voltage'] as num?)?.toStringAsFixed(2) ?? '-'}V',
                  flex: 2),
              _TC(
                  (scan['rpm'] as num?)?.toStringAsFixed(0) ?? '-',
                  flex: 2),
            ]),
          );
        }),
      ]),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
      flex: flex,
      child: Text(text,
          style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold)));
}

class _TC extends StatelessWidget {
  final String text;
  final int flex;
  const _TC(this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
      flex: flex,
      child: Text(text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12)));
}

class _CircularGauge extends StatelessWidget {
  final String label, value, unit;
  final double max, current;
  final double min;
  final Color color;
  final IconData icon;

  const _CircularGauge({
    required this.label,
    required this.value,
    required this.unit,
    required this.max,
    required this.current,
    required this.color,
    required this.icon,
    this.min = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = ((current - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.04 : 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow Halo
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 12,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.18)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Main Ring
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 8,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/obd_bluetooth_service.dart';
import 'widgets/jazzy_voice_assistant.dart';
import '../../../core/database/app_database.dart';

/// Main scaffold with bottom nav — wraps all primary screens
class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _navIndex = 0;

  final _pages = const [
    DashboardScreen(),
    _ObdLivePage(),
    _SchedulePage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          IndexedStack(index: _navIndex, children: _pages),
          const Positioned(
            bottom: 16,
            right: 16,
            child: JazzyVoiceAssistant(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.sensors, 'label': 'Live OBD'},
      {'icon': Icons.build_circle_rounded, 'label': 'Servis'},
      {'icon': Icons.person_rounded, 'label': 'Profil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isActive = _navIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _navIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.neonCyan.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'] as IconData,
                          size: 22,
                          color: isActive ? AppTheme.neonCyan : Colors.grey[600]),
                      const SizedBox(height: 3),
                      Text(item['label'] as String,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? AppTheme.neonCyan : Colors.grey[600])),
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

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD TAB
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<ObdConnectionState>? _stateSub;
  Timer? _uiTimer;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _stateSub = ObdBluetoothService.instance.connectionStateStream.listen((_) {
      if (mounted) { setState(() {}); _loadData(); }
    });
    _uiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final schedules = await AppDatabase.getSchedules('default-honda-jazz-ge8');
    final scans = await AppDatabase.getScans('default-honda-jazz-ge8');
    if (mounted) {
      setState(() {
        _schedules = schedules;
        _recentScans = scans.take(3).toList();
      });
    }
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
    final isLive = state == ObdConnectionState.connected || state == ObdConnectionState.simulating;
    final size = MediaQuery.of(context).size;

    // Derive health score from live OBD params
    final health = _calcHealthScore(obd);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(state, obd.simulatedOdometer),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width > 600 ? 32 : 16,
              vertical: 8,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Connection banner ─────────────────────────────────────────
                _ConnectionBanner(state: state, onTap: _toggleConnection),
                const SizedBox(height: 16),

                // ── Health ring ───────────────────────────────────────────────
                _HealthRingCard(score: health, odometer: obd.simulatedOdometer),
                const SizedBox(height: 20),

                // ── OBD sensor tiles (always visible, showing live or last memory scan) ──
                _SectionHeader(
                  title: state == ObdConnectionState.connected ? 'Live Sensor OBD-II' : 'Sensor OBD-II (Data Terakhir)',
                  trailing: state == ObdConnectionState.connected ? 'LIVE' : 'MEMORI',
                ),
                const SizedBox(height: 10),
                _ObdSensorGrid(obd: obd),
                const SizedBox(height: 20),

                // ── Upcoming service ──────────────────────────────────────────
                _SectionHeader(title: 'Jadwal Servis Berikutnya'),
                const SizedBox(height: 10),
                _UpcomingServiceCard(schedules: _schedules, odometer: obd.simulatedOdometer),
                const SizedBox(height: 20),

                // ── Quick actions ─────────────────────────────────────────────
                _SectionHeader(title: 'Aksi Cepat'),
                const SizedBox(height: 10),
                _QuickActions(context: context),
                const SizedBox(height: 20),

                // ── Recent scan history ───────────────────────────────────────
                if (_recentScans.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Riwayat Scan Terakhir', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => context.push('/scan-history'),
                        child: const Text('Lihat Semua', style: TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _RecentScansTable(scans: _recentScans),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  int _calcHealthScore(ObdBluetoothService obd) {
    int score = 100;
    if (obd.batteryVoltage < 12.0) score -= 25;
    else if (obd.batteryVoltage < 12.5) score -= 10;
    if (obd.coolantTemp > 105) score -= 20;
    else if (obd.coolantTemp > 100) score -= 8;
    if (obd.fuelTrim.abs() > 10) score -= 10;
    if (obd.dtcCodes.isNotEmpty) score -= 15;
    return score.clamp(0, 100);
  }

  Widget _buildSliverAppBar(ObdConnectionState state, int odometer) {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      snap: true,
      backgroundColor: AppTheme.darkBg,
      title: Row(children: [
        Image.asset('assets/images/app_icon.png', width: 28, height: 28,
            errorBuilder: (_, __, ___) => const Icon(Icons.speed, color: AppTheme.neonCyan, size: 24)),
        const SizedBox(width: 10),
        const Text('CHEK MOBILKU',
            style: TextStyle(color: AppTheme.neonCyan, fontSize: 16,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(FontAwesomeIcons.robot, color: AppTheme.neonCyan, size: 18),
          onPressed: () => context.push('/chatbot'),
          tooltip: 'AI Chatbot',
        ),
        IconButton(
          icon: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
          onPressed: () => context.push('/vehicles'),
          tooltip: 'Kendaraan',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _toggleConnection() {
    final s = ObdBluetoothService.instance.currentState;
    if (s == ObdConnectionState.disconnected) {
      ObdBluetoothService.instance.connectToObd();
    } else {
      ObdBluetoothService.instance.disconnect();
    }
    setState(() {});
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE OBD TAB — Full real-time sensor display
// ═══════════════════════════════════════════════════════════════════════════════
class _ObdLivePage extends StatefulWidget {
  const _ObdLivePage();

  @override
  State<_ObdLivePage> createState() => _ObdLivePageState();
}

class _ObdLivePageState extends State<_ObdLivePage> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final obd = ObdBluetoothService.instance;
    final state = obd.currentState;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          state == ObdConnectionState.connected ? 'Live OBD Monitor' : 'OBD Monitor (Data Terakhir)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _ConnectionPill(state: state)),
          ),
        ],
      ),
      body: _buildLiveView(obd),
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.bluetooth_disabled, size: 72, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Tidak Ada Perangkat OBD Terhubung',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tekan tombol di bawah untuk memulai scanning Bluetooth',
            style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Scan & Hubungkan OBD', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => ObdBluetoothService.instance.connectToObd(),
        ),
      ]),
    );
  }

  Widget _buildLiveView(ObdBluetoothService obd) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Speedometer + RPM gauges ────────────────────────────────────────
        Row(children: [
          Expanded(child: _GaugeCard(
            label: 'Kecepatan', value: obd.speed.toStringAsFixed(0),
            unit: 'km/h', max: 200, current: obd.speed,
            color: AppTheme.neonCyan, icon: Icons.speed,
          )),
          const SizedBox(width: 12),
          Expanded(child: _GaugeCard(
            label: 'RPM', value: obd.rpm.toStringAsFixed(0),
            unit: 'rpm', max: 6000, current: obd.rpm,
            color: AppTheme.neonOrange, icon: Icons.rotate_right,
          )),
        ]),
        const SizedBox(height: 12),

        // ── Temp + Battery ──────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _GaugeCard(
            label: 'Suhu Pendingin', value: obd.coolantTemp.toStringAsFixed(1),
            unit: '°C', max: 130, current: obd.coolantTemp,
            color: obd.coolantTemp > 100 ? AppTheme.neonOrange : AppTheme.neonGreen,
            icon: Icons.thermostat,
          )),
          const SizedBox(width: 12),
          Expanded(child: _GaugeCard(
            label: 'Tegangan Aki', value: obd.batteryVoltage.toStringAsFixed(2),
            unit: 'V', max: 16, current: obd.batteryVoltage,
            color: obd.batteryVoltage < 12.0 ? AppTheme.neonOrange : AppTheme.neonCyan,
            icon: FontAwesomeIcons.carBattery, min: 10,
          )),
        ]),
        const SizedBox(height: 12),

        // ── Fuel trim + DTC ─────────────────────────────────────────────────
        _DetailTile(
          icon: FontAwesomeIcons.gasPump,
          label: 'Fuel Trim',
          value: '${obd.fuelTrim > 0 ? '+' : ''}${obd.fuelTrim.toStringAsFixed(2)}%',
          status: obd.fuelTrim.abs() > 10 ? 'Perlu Cek' : 'Normal',
          statusColor: obd.fuelTrim.abs() > 10 ? AppTheme.neonOrange : AppTheme.neonGreen,
        ),
        const SizedBox(height: 10),
        _DetailTile(
          icon: Icons.report_problem_rounded,
          label: 'Kode DTC',
          value: obd.dtcCodes.isEmpty ? 'Tidak Ada Error' : obd.dtcCodes,
          status: obd.dtcCodes.isEmpty ? 'Normal' : 'ERROR',
          statusColor: obd.dtcCodes.isEmpty ? AppTheme.neonGreen : AppTheme.neonOrange,
        ),
        const SizedBox(height: 10),
        _DetailTile(
          icon: Icons.map_rounded,
          label: 'Odometer',
          value: '${obd.simulatedOdometer} km',
          status: 'Terbaca',
          statusColor: AppTheme.neonCyan,
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULE TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _SchedulePage extends StatefulWidget {
  const _SchedulePage();

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppDatabase.getSchedules('default-honda-jazz-ge8');
    setState(() { _schedules = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Jadwal Servis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : _schedules.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Belum ada jadwal servis',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Hubungkan OBD dan AI akan menganalisis kendaraan Anda',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              : RefreshIndicator(
                  color: AppTheme.neonCyan,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schedules.length,
                    itemBuilder: (_, i) => _ScheduleCard(schedule: _schedules[i]),
                  ),
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Profil & Pengaturan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileMenuCard(icon: Icons.directions_car_rounded, title: 'Manajemen Kendaraan',
              subtitle: 'Tambah/kelola data kendaraan Anda', color: AppTheme.neonCyan,
              onTap: () => context.push('/vehicles')),
          const SizedBox(height: 10),
          _ProfileMenuCard(icon: Icons.checklist_rounded, title: 'Inspeksi Kendaraan',
              subtitle: '23 poin pemeriksaan dianalisis AI', color: AppTheme.neonGreen,
              onTap: () => context.push('/inspection')),
          const SizedBox(height: 10),
          _ProfileMenuCard(icon: Icons.library_books_rounded, title: 'Catatan & Riwayat Servis',
              subtitle: 'Catat ganti oli, aki, rem + Analisis AI', color: AppTheme.neonCyan,
              onTap: () => context.push('/service-logs')),
          const SizedBox(height: 10),
          _ProfileMenuCard(icon: FontAwesomeIcons.robot, title: 'AI Chatbot Mekanik',
              subtitle: 'Tanya AI soal masalah kendaraan', color: AppTheme.neonOrange,
              onTap: () => context.push('/chatbot')),
          const SizedBox(height: 10),
          _ProfileMenuCard(icon: Icons.bluetooth_searching, title: 'Koneksi Bluetooth OBD',
              subtitle: 'Scan dan hubungkan adaptor ELM327', color: Colors.blueAccent,
              onTap: () {
                final s = ObdBluetoothService.instance.currentState;
                if (s == ObdConnectionState.disconnected) {
                  ObdBluetoothService.instance.connectToObd();
                } else {
                  ObdBluetoothService.instance.startSimulationMode();
                }
              }),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tentang Aplikasi', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Smart OBD Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('AI Vehicle Intelligence v1.0.0', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 4),
              Text('Powered by Groq · Llama 3 70B', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _ConnectionBanner extends StatelessWidget {
  final ObdConnectionState state;
  final VoidCallback onTap;
  const _ConnectionBanner({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(state);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (cfg['color'] as Color).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (cfg['color'] as Color).withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: cfg['color'] as Color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cfg['title'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(cfg['subtitle'] as String,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ]),
          ),
          Icon(cfg['trailing'] as IconData, color: cfg['color'] as Color, size: 18),
        ]),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Map<String, dynamic> _config(ObdConnectionState s) {
    switch (s) {
      case ObdConnectionState.connected:
        return {'color': AppTheme.neonGreen, 'title': 'OBD-II Bluetooth Terhubung',
            'subtitle': 'Menerima data sensor secara real-time', 'trailing': Icons.bluetooth_connected};
      case ObdConnectionState.simulating:
        return {'color': AppTheme.neonYellow, 'title': 'Mode Simulasi Aktif',
            'subtitle': 'Ketuk untuk mencoba koneksi Bluetooth nyata', 'trailing': Icons.bolt};
      case ObdConnectionState.scanning:
        return {'color': AppTheme.neonCyan, 'title': 'Memindai Perangkat Bluetooth...',
            'subtitle': 'Menunggu adaptor ELM327 di dekat Anda', 'trailing': Icons.bluetooth_searching};
      case ObdConnectionState.connecting:
        return {'color': AppTheme.neonCyan, 'title': 'Menghubungkan ke Adaptor...',
            'subtitle': 'Mohon tunggu sebentar', 'trailing': Icons.bluetooth_searching};
      default:
        return {'color': Colors.grey, 'title': 'Adaptor OBD Belum Terhubung',
            'subtitle': 'Ketuk untuk memulai scanning Bluetooth', 'trailing': Icons.bluetooth_disabled};
    }
  }
}

class _ConnectionPill extends StatelessWidget {
  final ObdConnectionState state;
  const _ConnectionPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state == ObdConnectionState.connected
        ? AppTheme.neonGreen
        : state == ObdConnectionState.simulating
            ? AppTheme.neonYellow
            : state == ObdConnectionState.scanning
                ? AppTheme.neonCyan
                : Colors.grey;
    final label = state == ObdConnectionState.connected ? 'BT LIVE'
        : state == ObdConnectionState.simulating ? 'SIMULASI'
        : state == ObdConnectionState.scanning ? 'SCANNING...'
        : 'OFFLINE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ]),
    );
  }
}

class _HealthRingCard extends StatelessWidget {
  final int score;
  final int odometer;
  const _HealthRingCard({required this.score, required this.odometer});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85 ? AppTheme.neonGreen : score >= 65 ? AppTheme.neonYellow : AppTheme.neonOrange;
    final label = score >= 85 ? 'Kondisi Prima' : score >= 65 ? 'Perlu Perhatian' : 'Segera Servis';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 24, spreadRadius: 4)],
      ),
      child: Row(children: [
        // Ring gauge
        SizedBox(
          width: 110, height: 110,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 110, height: 110,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 10,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text('/ 100', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ]),
          ]),
        ).animate().scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          const Text('Kesehatan Kendaraan', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Honda Jazz GE8', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.speed, size: 13, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('$odometer km', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ])),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _ObdSensorGrid extends StatelessWidget {
  final ObdBluetoothService obd;
  const _ObdSensorGrid({required this.obd});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _SensorTile('RPM',
          obd.rpm.toStringAsFixed(0), 'rpm', Icons.rotate_right, AppTheme.neonOrange,
          (obd.rpm / 6000).clamp(0.0, 1.0)),
      _SensorTile('Kecepatan',
          obd.speed.toStringAsFixed(0), 'km/h', Icons.speed, AppTheme.neonCyan,
          (obd.speed / 200).clamp(0.0, 1.0)),
      _SensorTile('Coolant',
          obd.coolantTemp.toStringAsFixed(1), '°C', Icons.thermostat,
          obd.coolantTemp > 100 ? AppTheme.neonOrange : AppTheme.neonGreen,
          (obd.coolantTemp / 130).clamp(0.0, 1.0)),
      _SensorTile('Aki',
          obd.batteryVoltage.toStringAsFixed(2), 'V', FontAwesomeIcons.carBattery,
          obd.batteryVoltage < 12.0 ? AppTheme.neonOrange : AppTheme.neonCyan,
          ((obd.batteryVoltage - 10) / 6).clamp(0.0, 1.0)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: tiles.map((t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.color.withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Icon(t.icon, size: 14, color: t.color),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: t.value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              TextSpan(text: ' ${t.unit}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ])),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: t.progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(t.color),
            ),
          ]),
        ]),
      )).toList(),
    ).animate().fade(delay: 100.ms);
  }
}

class _SensorTile {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final double progress;
  _SensorTile(this.label, this.value, this.unit, this.icon, this.color, [this.progress = 0.5]);
}


class _GaugeCard extends StatelessWidget {
  final String label, value, unit;
  final double max, current;
  final double min;
  final Color color;
  final IconData icon;
  const _GaugeCard({required this.label, required this.value, required this.unit,
      required this.max, required this.current, required this.color, required this.icon, this.min = 0});

  @override
  Widget build(BuildContext context) {
    final ratio = ((current - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 90, height: 90,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 9,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(unit, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ]),
        ]),
      ]),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label, value, status;
  final Color statusColor;
  const _DetailTile({required this.icon, required this.label, required this.value,
      required this.status, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(children: [
        Icon(icon, color: statusColor, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      if (trailing != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.neonCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
          ),
          child: Text(trailing!, style: const TextStyle(color: AppTheme.neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
    ]);
  }
}

class _UpcomingServiceCard extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;
  final int odometer;
  const _UpcomingServiceCard({required this.schedules, required this.odometer});

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Text('Belum ada jadwal. Hubungkan OBD untuk AI analisis.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    // Sort by next predicted date
    final sorted = List<Map<String, dynamic>>.from(schedules)
      ..sort((a, b) {
        final da = a['next_predicted_date'] as String? ?? '';
        final db = b['next_predicted_date'] as String? ?? '';
        return da.compareTo(db);
      });

    final next = sorted.first;
    final name = next['service_name'] as String;
    final desc = next['description'] as String? ?? '';
    final nextMil = next['next_predicted_mileage'] as int? ?? 0;
    final nextDate = next['next_predicted_date'] != null
        ? DateTime.tryParse(next['next_predicted_date'] as String) : null;
    final daysLeft = nextDate != null ? nextDate.difference(DateTime.now()).inDays : null;
    final milLeft = nextMil - odometer;
    final urgent = (daysLeft != null && daysLeft <= 14) || milLeft <= 1000;
    final color = urgent ? AppTheme.neonOrange : AppTheme.neonGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(urgent ? Icons.warning_rounded : Icons.check_circle_outline,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
        const SizedBox(height: 8),
        if (desc.isNotEmpty)
          Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(children: [
          _StatChip(Icons.calendar_today, daysLeft != null ? '$daysLeft hari lagi' : '-', color),
          const SizedBox(width: 8),
          _StatChip(Icons.speed, milLeft > 0 ? '+$milLeft km' : 'Sekarang!', color),
        ]),
        if (sorted.length > 1) ...[
          const SizedBox(height: 10),
          Text('+${sorted.length - 1} jadwal servis lainnya',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ]),
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
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final BuildContext context;
  const _QuickActions({required this.context});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'icon': Icons.checklist_rounded, 'label': 'Inspeksi', 'color': AppTheme.neonCyan, 'route': '/inspection'},
      {'icon': FontAwesomeIcons.robot, 'label': 'Tanya AI', 'color': AppTheme.neonOrange, 'route': '/chatbot'},
      {'icon': Icons.directions_car_rounded, 'label': 'Kendaraan', 'color': AppTheme.neonGreen, 'route': '/vehicles'},
    ];

    return Row(children: actions.map((a) => Expanded(
      child: GestureDetector(
        onTap: () => context.push(a['route'] as String),
        child: Container(
          margin: EdgeInsets.only(right: a == actions.last ? 0 : 10),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (a['color'] as Color).withOpacity(0.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(a['icon'] as IconData, color: a['color'] as Color, size: 22),
            const SizedBox(height: 6),
            Text(a['label'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    )).toList());
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
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _TableHeader('Waktu', flex: 3),
            _TableHeader('Coolant', flex: 2),
            _TableHeader('Aki (V)', flex: 2),
            _TableHeader('RPM', flex: 2),
          ]),
        ),
        ...scans.asMap().entries.map((e) {
          final scan = e.value;
          final isLast = e.key == scans.length - 1;
          final date = DateTime.tryParse(scan['scan_date'] as String? ?? '');
          final timeStr = date != null
              ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
              : '-';
          return Container(
            decoration: BoxDecoration(
              border: isLast ? null : Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _TableCell(timeStr, flex: 3),
              _TableCell('${(scan['coolant_temp'] as num?)?.toStringAsFixed(1)}°C', flex: 2),
              _TableCell('${(scan['battery_voltage'] as num?)?.toStringAsFixed(2)}V', flex: 2),
              _TableCell('${(scan['rpm'] as num?)?.toStringAsFixed(0)}', flex: 2),
            ]),
          );
        }),
      ]),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;
  const _TableHeader(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)));
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final int flex;
  const _TableCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)));
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final name = schedule['service_name'] as String;
    final desc = schedule['description'] as String? ?? '';
    final nextDate = schedule['next_predicted_date'] != null
        ? DateTime.tryParse(schedule['next_predicted_date'] as String) : null;
    final nextMil = schedule['next_predicted_mileage'] as int?;
    final intervalMil = schedule['interval_mileage'] as int?;
    final daysLeft = nextDate != null ? nextDate.difference(DateTime.now()).inDays : null;
    final urgent = daysLeft != null && daysLeft <= 14;
    final color = urgent ? AppTheme.neonOrange : AppTheme.neonGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(urgent ? Icons.warning_rounded : Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (daysLeft != null)
            _StatChip(Icons.calendar_today, '$daysLeft hari lagi', color),
          if (nextMil != null)
            _StatChip(Icons.speed, '$nextMil km', color),
          if (intervalMil != null)
            _StatChip(Icons.loop, 'Interval: $intervalMil km', AppTheme.neonCyan),
        ]),
      ]),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ProfileMenuCard({required this.icon, required this.title, required this.subtitle,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
        ]),
      ),
    );
  }
}

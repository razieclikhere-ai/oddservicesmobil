// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/obd_live_page.dart
// Real-time OBD-II sensor dashboard — responsive, reactive, auto-updating
// ────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/obd_bluetooth_service.dart';
import '../../../core/providers/app_providers.dart';

class ObdLivePage extends ConsumerStatefulWidget {
  const ObdLivePage({super.key});

  @override
  ConsumerState<ObdLivePage> createState() => _ObdLivePageState();
}

class _ObdLivePageState extends ConsumerState<ObdLivePage> {
  Timer? _ticker;
  StreamSubscription<ObdConnectionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    // Refresh the UI periodically for smooth real-time ticks
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _stateSub = ObdBluetoothService.instance.connectionStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(obdConnectionStateProvider);
    final obd = ObdBluetoothService.instance;
    final state = connectionState.valueOrNull ?? obd.currentState;

    final isOffline = state == ObdConnectionState.disconnected &&
        obd.rpm == 0 &&
        obd.batteryVoltage == 0;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          state == ObdConnectionState.connected
              ? 'Live OBD Monitor'
              : 'OBD Monitor (Data Terakhir)',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _ConnectionPill(state: state)),
          ),
        ],
      ),
      body: isOffline
          ? _buildDisconnectedView()
          : _buildLiveView(obd, state),
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled,
                size: 80, color: Colors.grey)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1500.ms),
            const SizedBox(height: 20),
            const Text(
              'OBD Belum Terhubung',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hubungkan adapter ELM327 Bluetooth untuk menampilkan data sensor real-time secara dinamis.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Hubungkan OBD Sekarang',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () =>
                  ObdBluetoothService.instance.connectToObd(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveView(ObdBluetoothService obd, ObdConnectionState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Circular Gauges: Speed & RPM
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
          const SizedBox(height: 16),

          // Linear Sensor Cards: Coolant & Battery
          Row(children: [
            Expanded(
              child: _LinearSensorCard(
                label: 'Radiator (Coolant)',
                value: '${obd.coolantTemp.toStringAsFixed(1)} °C',
                max: 120,
                current: obd.coolantTemp,
                color: obd.coolantTemp > 100
                    ? AppTheme.neonOrange
                    : AppTheme.neonGreen,
                icon: Icons.thermostat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LinearSensorCard(
                label: 'Tegangan Aki',
                value: '${obd.batteryVoltage.toStringAsFixed(2)} V',
                max: 16,
                min: 10,
                current: obd.batteryVoltage,
                color: obd.batteryVoltage < 12.0
                    ? AppTheme.neonOrange
                    : AppTheme.neonCyan,
                icon: FontAwesomeIcons.carBattery,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Details List
          _DetailTile(
            icon: FontAwesomeIcons.gasPump,
            label: 'Short-term Fuel Trim',
            value:
                '${obd.fuelTrim > 0 ? '+' : ''}${obd.fuelTrim.toStringAsFixed(2)}%',
            status:
                obd.fuelTrim.abs() > 10 ? 'Perlu Cek' : 'Normal',
            statusColor: obd.fuelTrim.abs() > 10
                ? AppTheme.neonOrange
                : AppTheme.neonGreen,
          ),
          const SizedBox(height: 12),

          _DetailTile(
            icon: Icons.report_problem_rounded,
            label: 'Status DTC (Malfungsi)',
            value: obd.dtcCodes.isEmpty
                ? 'Tidak Ada Kode Kerusakan'
                : obd.dtcCodes,
            status: obd.dtcCodes.isEmpty ? 'Sehat' : 'WARNING',
            statusColor: obd.dtcCodes.isEmpty
                ? AppTheme.neonGreen
                : AppTheme.neonOrange,
          ),
          const SizedBox(height: 12),

          _DetailTile(
            icon: Icons.map_rounded,
            label: 'Odometer Kendaraan',
            value: '${obd.currentOdometer} km',
            status: state == ObdConnectionState.connected
                ? 'Aktif'
                : 'Memori',
            statusColor: state == ObdConnectionState.connected
                ? AppTheme.neonCyan
                : Colors.grey,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _ConnectionPill extends StatelessWidget {
  final ObdConnectionState state;
  const _ConnectionPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      ObdConnectionState.connected => (AppTheme.neonGreen, 'LIVE'),
      ObdConnectionState.simulating => (AppTheme.neonYellow, 'SIMULASI'),
      ObdConnectionState.scanning => (AppTheme.neonCyan, 'PINDAI...'),
      ObdConnectionState.connecting => (AppTheme.neonCyan, 'KONEKSI...'),
      _ => (Colors.grey, 'OFFLINE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
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
    final ratio = ((current - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.03),
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
                style: const TextStyle(
                    color: Colors.grey,
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
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.03),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                          color: Colors.grey[500],
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

class _LinearSensorCard extends StatelessWidget {
  final String label, value;
  final double max, current;
  final double min;
  final Color color;
  final IconData icon;

  const _LinearSensorCard({
    required this.label,
    required this.value,
    required this.max,
    required this.current,
    required this.color,
    required this.icon,
    this.min = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = ((current - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.white.withOpacity(0.04),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label, value, status;
  final Color statusColor;
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: statusColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

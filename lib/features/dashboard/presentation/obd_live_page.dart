// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/obd_live_page.dart
// Real-time OBD sensor monitor tab
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
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
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(obdConnectionStateProvider);
    final obd = ObdBluetoothService.instance;

    final state = connectionState.valueOrNull ?? obd.currentState;

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
      body: state == ObdConnectionState.disconnected &&
              obd.rpm == 0 &&
              obd.batteryVoltage == 0
          ? _buildDisconnectedView()
          : _buildLiveView(obd, state),
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled,
              size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Perangkat OBD Terhubung',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk memulai scanning Bluetooth',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Scan & Hubungkan OBD',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () =>
                ObdBluetoothService.instance.connectToObd(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView(ObdBluetoothService obd, ObdConnectionState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Speedometer + RPM
          Row(children: [
            Expanded(
              child: _GaugeCard(
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
              child: _GaugeCard(
                label: 'RPM',
                value: obd.rpm.toStringAsFixed(0),
                unit: 'rpm',
                max: 6000,
                current: obd.rpm,
                color: AppTheme.neonOrange,
                icon: Icons.rotate_right,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Coolant + Battery
          Row(children: [
            Expanded(
              child: _GaugeCard(
                label: 'Suhu Pendingin',
                value: obd.coolantTemp.toStringAsFixed(1),
                unit: '°C',
                max: 130,
                current: obd.coolantTemp,
                color: obd.coolantTemp > 100
                    ? AppTheme.neonOrange
                    : AppTheme.neonGreen,
                icon: Icons.thermostat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GaugeCard(
                label: 'Tegangan Aki',
                value: obd.batteryVoltage.toStringAsFixed(2),
                unit: 'V',
                max: 16,
                current: obd.batteryVoltage,
                min: 10,
                color: obd.batteryVoltage < 12.0
                    ? AppTheme.neonOrange
                    : AppTheme.neonCyan,
                icon: FontAwesomeIcons.carBattery,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Fuel trim
          _DetailTile(
            icon: FontAwesomeIcons.gasPump,
            label: 'Fuel Trim',
            value:
                '${obd.fuelTrim > 0 ? '+' : ''}${obd.fuelTrim.toStringAsFixed(2)}%',
            status:
                obd.fuelTrim.abs() > 10 ? 'Perlu Cek' : 'Normal',
            statusColor: obd.fuelTrim.abs() > 10
                ? AppTheme.neonOrange
                : AppTheme.neonGreen,
          ),
          const SizedBox(height: 10),

          // DTC codes
          _DetailTile(
            icon: Icons.report_problem_rounded,
            label: 'Kode DTC',
            value: obd.dtcCodes.isEmpty
                ? 'Tidak Ada Error'
                : obd.dtcCodes,
            status: obd.dtcCodes.isEmpty ? 'Normal' : 'ERROR',
            statusColor: obd.dtcCodes.isEmpty
                ? AppTheme.neonGreen
                : AppTheme.neonOrange,
          ),
          const SizedBox(height: 10),

          // Odometer
          _DetailTile(
            icon: Icons.map_rounded,
            label: 'Odometer',
            value: '${obd.currentOdometer} km',
            status: state == ObdConnectionState.connected
                ? 'Live'
                : 'Terakhir',
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
      ObdConnectionState.connected => (AppTheme.neonGreen, 'BT LIVE'),
      ObdConnectionState.simulating =>
        (AppTheme.neonYellow, 'SIMULASI'),
      ObdConnectionState.scanning =>
        (AppTheme.neonCyan, 'SCANNING...'),
      ObdConnectionState.connecting =>
        (AppTheme.neonCyan, 'CONNECTING...'),
      _ => (Colors.grey, 'OFFLINE'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
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

class _GaugeCard extends StatelessWidget {
  final String label, value, unit;
  final double max, current;
  final double min;
  final Color color;
  final IconData icon;
  const _GaugeCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor:
                Colors.white.withOpacity(0.05),
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
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.05)),
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
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

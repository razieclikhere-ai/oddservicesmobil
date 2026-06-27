import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/obd_bluetooth_service.dart';
import '../../../core/database/app_database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedVehicle = "Honda Jazz GE8 2020";
  StreamSubscription<ObdConnectionState>? _stateSubscription;
  Timer? _uiRefreshTimer;
  List<Map<String, dynamic>> _predictions = [];

  final List<Map<String, dynamic>> _vehicles = [
    {"name": "Honda Jazz GE8 2020", "score": 92, "status": "Sehat", "brand": "Honda", "uuid": "default-honda-jazz-ge8"},
    {"name": "Toyota Avanza 2020", "score": 85, "status": "Perlu Servis", "brand": "Toyota", "uuid": "toyota-avanza-uuid"},
    {"name": "Mitsubishi Pajero 2018", "score": 97, "status": "Prima", "brand": "Mitsubishi", "uuid": "pajero-uuid"},
  ];

  Map<String, dynamic> get _currentVehicle =>
      _vehicles.firstWhere((v) => v['name'] == _selectedVehicle);

  @override
  void initState() {
    super.initState();
    // Listen to connection updates
    _stateSubscription = ObdBluetoothService.instance.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {});
        _loadPredictions();
      }
    });

    // Refresh UI parameters periodically (RPM, Speed updates etc.)
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    final vehicleUuid = _currentVehicle['uuid'] as String;
    final schedules = await AppDatabase.getSchedules(vehicleUuid);
    if (mounted) {
      setState(() {
        _predictions = schedules;
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih Kendaraan',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Pilih kendaraan yang ingin dipantau',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),
            ..._vehicles.map((v) {
              final isSelected = v['name'] == _selectedVehicle;
              return InkWell(
                onTap: () {
                  setState(() => _selectedVehicle = v['name']);
                  _loadPredictions();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.neonCyan.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonCyan.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.car,
                          size: 18, color: isSelected ? AppTheme.neonCyan : Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(v['name'],
                              style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[400],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                      Text('${v['score']}%',
                          style: TextStyle(
                              color: isSelected ? AppTheme.neonCyan : Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _toggleObdConnection() {
    final state = ObdBluetoothService.instance.currentState;
    if (state == ObdConnectionState.disconnected) {
      ObdBluetoothService.instance.connectToObd();
    } else {
      ObdBluetoothService.instance.disconnect();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _currentVehicle;
    final int score = vehicle['score'];
    final obdState = ObdBluetoothService.instance.currentState;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'SMART OBD',
          style: TextStyle(
              letterSpacing: 3,
              fontSize: 18,
              color: AppTheme.neonCyan,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.robot, color: AppTheme.neonCyan, size: 20),
            onPressed: () => context.push('/chatbot'),
            tooltip: 'AI Chatbot',
          ),
          IconButton(
            icon: Icon(
              obdState == ObdConnectionState.connected
                  ? Icons.bluetooth_connected
                  : obdState == ObdConnectionState.simulating
                      ? Icons.bolt
                      : Icons.bluetooth_disabled,
              color: obdState == ObdConnectionState.connected
                  ? AppTheme.neonGreen
                  : obdState == ObdConnectionState.simulating
                      ? AppTheme.neonYellow
                      : Colors.grey,
            ),
            onPressed: _toggleObdConnection,
            tooltip: 'Status Koneksi OBD',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.neonCyan,
        onRefresh: () async {
          await _loadPredictions();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildHealthCard(score),
              const SizedBox(height: 24),
              _buildSectionTitle('Live Telemetry'),
              const SizedBox(height: 12),
              _buildTelemetryGrid(),
              const SizedBox(height: 24),
              _buildSectionTitle('AI Predicted Service & Schedules'),
              const SizedBox(height: 12),
              _buildPredictionList(),
              const SizedBox(height: 24),
              _buildSectionTitle('Inspeksi Kendaraan'),
              const SizedBox(height: 12),
              _buildInspectionBanner(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleObdConnection,
        backgroundColor: obdState == ObdConnectionState.disconnected
            ? AppTheme.neonCyan
            : AppTheme.neonOrange,
        foregroundColor: Colors.black,
        icon: Icon(
          obdState == ObdConnectionState.disconnected
              ? Icons.bluetooth_searching
              : Icons.power_settings_new,
          size: 20,
        ),
        label: Text(
          obdState == ObdConnectionState.disconnected
              ? 'Scan OBD-II'
              : obdState == ObdConnectionState.scanning
                  ? 'Scanning...'
                  : 'Disconnect OBD',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.1);
  }

  Widget _buildHeader() {
    final obdState = ObdBluetoothService.instance.currentState;
    String statusStr = 'Disambungkan';
    Color statusColor = Colors.grey;

    if (obdState == ObdConnectionState.scanning) {
      statusStr = 'Mencari Perangkat BLE...';
      statusColor = AppTheme.neonCyan;
    } else if (obdState == ObdConnectionState.connecting) {
      statusStr = 'Menghubungkan...';
      statusColor = AppTheme.neonCyan;
    } else if (obdState == ObdConnectionState.connected) {
      statusStr = 'OBD-II Terkoneksi';
      statusColor = AppTheme.neonGreen;
    } else if (obdState == ObdConnectionState.simulating) {
      statusStr = 'Simulasi Telemetry Aktif';
      statusColor = AppTheme.neonYellow;
    } else {
      statusStr = 'Adaptor OBD Terputus';
      statusColor = Colors.grey;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusStr, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Pengendara Cerdas 🚗',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        GestureDetector(
          onTap: _showVehicleSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.car, size: 13, color: AppTheme.neonCyan),
                const SizedBox(width: 6),
                Text(_currentVehicle['brand'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildHealthCard(int score) {
    Color scoreColor = score >= 90
        ? AppTheme.neonGreen
        : score >= 75
            ? AppTheme.neonYellow
            : AppTheme.neonOrange;
    String statusText = score >= 90 ? 'Sistem Prima' : score >= 75 ? 'Perlu Perhatian' : 'Segera Servis';

    final odometer = ObdBluetoothService.instance.simulatedOdometer;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.12), blurRadius: 30, spreadRadius: 2)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kesehatan Kendaraan', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(_selectedVehicle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Mileage: $odometer km', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: scoreColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score%',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Health', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ],
            ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildTelemetryGrid() {
    final obd = ObdBluetoothService.instance;
    final data = [
      {'title': 'Engine Load', 'value': '${(obd.rpm / 60).toStringAsFixed(0)}%', 'icon': FontAwesomeIcons.gauge, 'color': AppTheme.neonCyan},
      {'title': 'Coolant Temp', 'value': '${obd.coolantTemp.toStringAsFixed(1)}°C', 'icon': FontAwesomeIcons.thermometerEmpty, 'color': obd.coolantTemp > 100 ? AppTheme.neonOrange : AppTheme.neonGreen},
      {'title': 'Battery', 'value': '${obd.batteryVoltage.toStringAsFixed(2)}V', 'icon': FontAwesomeIcons.carBattery, 'color': obd.batteryVoltage < 12.0 ? AppTheme.neonOrange : AppTheme.neonCyan},
      {'title': 'RPM', 'value': obd.rpm.toStringAsFixed(0), 'icon': FontAwesomeIcons.bolt, 'color': AppTheme.neonOrange},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: data.map((item) => _buildTelemetryCard(
        item['title'] as String,
        item['value'] as String,
        item['icon'] as IconData,
        item['color'] as Color,
      )).toList(),
    ).animate().fade(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildTelemetryCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Icon(icon, size: 14, color: color),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Container(width: 36, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionList() {
    if (_predictions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Center(
          child: Text(
            'Belum ada data prediksi AI. Hubungkan OBD-II untuk memicu analisis.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final pred = _predictions[index];
        final name = pred['service_name'] as String;
        final desc = pred['description'] as String;
        final predDateStr = pred['next_predicted_date'] as String?;
        final predMil = pred['next_predicted_mileage'] as int?;

        String formattedDate = 'TBD';
        if (predDateStr != null) {
          final dt = DateTime.parse(predDateStr);
          formattedDate = '${dt.day}/${dt.month}/${dt.year}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(FontAwesomeIcons.circleExclamation, color: AppTheme.neonCyan, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(formattedDate, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Icon(Icons.speed, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(predMil != null ? '$predMil km' : 'TBD', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildInspectionBanner() {
    return GestureDetector(
      onTap: () => context.push('/inspection'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.neonCyan.withOpacity(0.12), AppTheme.neonGreen.withOpacity(0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.checklist_rounded, color: AppTheme.neonCyan, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mulai Inspeksi Kendaraan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('23 poin pemeriksaan • Dianalisis AI',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.neonCyan, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05);
  }
}

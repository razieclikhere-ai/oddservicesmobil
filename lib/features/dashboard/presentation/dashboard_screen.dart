import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedVehicle = "Honda Jazz GE8 2020";

  final List<Map<String, dynamic>> _vehicles = [
    {"name": "Honda Jazz GE8 2020", "score": 92, "status": "Sehat", "brand": "Honda"},
    {"name": "Toyota Avanza 2020", "score": 85, "status": "Perlu Servis", "brand": "Toyota"},
    {"name": "Mitsubishi Pajero 2018", "score": 97, "status": "Prima", "brand": "Mitsubishi"},
  ];

  Map<String, dynamic> get _currentVehicle =>
      _vehicles.firstWhere((v) => v['name'] == _selectedVehicle);

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

  @override
  Widget build(BuildContext context) {
    final vehicle = _currentVehicle;
    final int score = vehicle['score'];

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
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
            tooltip: 'Notifikasi',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.neonCyan,
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 800)),
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
              _buildSectionTitle('Komponen Kendaraan'),
              const SizedBox(height: 12),
              _buildComponentRow(),
              const SizedBox(height: 24),
              _buildSectionTitle('AI Diagnostics & Alerts'),
              const SizedBox(height: 12),
              _buildAIAlerts(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.bluetooth_searching, size: 20),
        label: const Text('Scan OBD-II', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat Datang,', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
            ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.outBack),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildTelemetryGrid() {
    final data = [
      {'title': 'Engine Load', 'value': '24%', 'icon': FontAwesomeIcons.gauge, 'color': AppTheme.neonCyan},
      {'title': 'Coolant Temp', 'value': '89°C', 'icon': FontAwesomeIcons.thermometerEmpty, 'color': AppTheme.neonGreen},
      {'title': 'Battery', 'value': '12.4V', 'icon': FontAwesomeIcons.carBattery, 'color': AppTheme.neonCyan},
      {'title': 'RPM', 'value': '1,200', 'icon': FontAwesomeIcons.bolt, 'color': AppTheme.neonOrange},
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

  Widget _buildComponentRow() {
    final components = [
      {'label': 'Mesin', 'icon': Icons.settings, 'status': 'normal', 'value': 'OK'},
      {'label': 'Rem', 'icon': Icons.radio_button_checked, 'status': 'normal', 'value': 'OK'},
      {'label': 'Oli', 'icon': FontAwesomeIcons.oilCan, 'status': 'warning', 'value': '~9K'},
      {'label': 'Ban', 'icon': FontAwesomeIcons.circleHalfStroke, 'status': 'normal', 'value': 'OK'},
    ];

    return Row(
      children: components.map((c) {
        final color = c['status'] == 'critical'
            ? AppTheme.neonOrange
            : c['status'] == 'warning'
                ? AppTheme.neonYellow
                : AppTheme.neonGreen;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(c['icon'] as IconData, color: color, size: 22),
                const SizedBox(height: 6),
                Text(c['label'] as String, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                Text(c['value'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    ).animate().fade(delay: 150.ms);
  }

  Widget _buildAIAlerts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neonOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neonOrange.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(FontAwesomeIcons.triangleExclamation, color: AppTheme.neonOrange, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Oli Mesin Hampir Habis Interval',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 5),
                Text('Sudah ~9.000 km sejak penggantian oli terakhir. Direkomendasikan servis dalam 1.000 km ke depan.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context.push('/chatbot'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
                    ),
                    child: const Text('Tanya AI →',
                        style: TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

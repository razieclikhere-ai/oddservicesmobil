import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedVehicle = "Toyota Avanza 2020";

  final List<Map<String, dynamic>> _vehicles = [
    {"name": "Toyota Avanza 2020", "score": 92, "status": "Sehat"},
    {"name": "Honda Jazz GE8 2008", "score": 85, "status": "Perlu Servis"},
    {"name": "Mitsubishi Pajero 2018", "score": 97, "status": "Sangat Sehat"},
  ];

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: minAxisSize,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Kendaraan Anda',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ..._vehicles.map((v) {
                final isSelected = v['name'] == _selectedVehicle;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    FontAwesomeIcons.car,
                    color: isSelected ? AppTheme.neonCyan : Colors.grey,
                  ),
                  title: Text(
                    v['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Text(
                    '${v['score']}%',
                    style: TextStyle(
                      color: isSelected ? AppTheme.neonCyan : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedVehicle = v['name'];
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Get current vehicle details
  Map<String, dynamic> get _currentVehicleData =>
      _vehicles.firstWhere((v) => v['name'] == _selectedVehicle);

  @override
  Widget build(BuildContext context) {
    final vehicle = _currentVehicleData;
    final int score = vehicle['score'];

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Image.network(
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=100', // Mock Logo or text
          height: 30,
          errorBuilder: (context, error, stackTrace) => const Text(
            'SMART OBD',
            style: TextStyle(letterSpacing: 2, fontSize: 18, color: AppTheme.neonCyan),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.robot, color: AppTheme.neonCyan),
            onPressed: () => context.push('/chatbot'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(vehicle['name']),
              const SizedBox(height: 20),
              _buildGlowingHealthCard(score),
              const SizedBox(height: 24),
              Text(
                'Live Telemetry',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2),
              const SizedBox(height: 12),
              _buildLiveTelemetryGrid(),
              const SizedBox(height: 24),
              Text(
                'AI Diagnostics & Alerts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2),
              const SizedBox(height: 12),
              _buildAIAlerts(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.bluetooth_searching, size: 20),
        label: const Text('Hubungkan OBD-II', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat Pagi,',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const Text(
              'Pengendara Cerdas',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        InkWell(
          onTap: _showVehicleSelector,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.car, size: 14, color: AppTheme.neonCyan),
                const SizedBox(width: 8),
                Text(
                  name.split(' ')[0], // Merek saja
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        )
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildGlowingHealthCard(int score) {
    Color scoreColor = score >= 90
        ? AppTheme.neonGreen
        : score >= 80
            ? AppTheme.neonYellow
            : AppTheme.neonOrange;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient design elements
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kondisi Keseluruhan',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedVehicle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            score >= 90 ? 'Sistem Prima' : 'Membutuhkan Atensi',
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Glowing Circular Gauge
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
                          Text(
                            '$score%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Health',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.outBack),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildLiveTelemetryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildTelemetryCard('Engine Load', '24%', FontAwesomeIcons.gauge, AppTheme.neonCyan),
        _buildTelemetryCard('Coolant Temp', '89 °C', FontAwesomeIcons.thermometerEmpty, AppTheme.neonGreen),
        _buildTelemetryCard('Battery Voltage', '12.4 V', FontAwesomeIcons.carBattery, AppTheme.neonCyan),
        _buildTelemetryCard('Engine RPM', '1,200', FontAwesomeIcons.bolt, AppTheme.neonOrange),
      ],
    ).animate().fade(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildTelemetryCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Icon(icon, size: 16, color: accentColor),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAIAlerts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neonOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neonOrange.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(FontAwesomeIcons.triangleExclamation, color: AppTheme.neonOrange),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aki Mulai Melemah',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tegangan terdeteksi di bawah 12.2V saat start dingin. Disarankan mengecas aki segera.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}
const MainAxisSize minAxisSize = MainAxisSize.min;

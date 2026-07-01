import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _bluetoothGranted = false;
  bool _locationGranted = false;
  bool _microphoneGranted = false;
  bool _notificationGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final btConnect = await Permission.bluetoothConnect.isGranted;
    final btScan = await Permission.bluetoothScan.isGranted;
    final bluetoothStatus = await Permission.bluetooth.isGranted;
    
    final loc = await Permission.location.isGranted;
    final mic = await Permission.microphone.isGranted;
    final notif = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        _bluetoothGranted = (btConnect && btScan) || bluetoothStatus;
        _locationGranted = loc;
        _microphoneGranted = mic;
        _notificationGranted = notif;
        _checking = false;
      });
    }
  }

  Future<void> _requestBluetooth() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetooth,
    ].request();
    await _checkPermissions();
  }

  Future<void> _requestLocation() async {
    await Permission.location.request();
    await _checkPermissions();
  }

  Future<void> _requestMicrophone() async {
    await Permission.microphone.request();
    await _checkPermissions();
  }

  Future<void> _requestNotification() async {
    await Permission.notification.request();
    await _checkPermissions();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _bluetoothGranted && _locationGranted && _microphoneGranted && _notificationGranted;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF0F1A2B), AppTheme.darkBg],
              ),
            ),
          ),
          
          SafeArea(
            child: _checking
                ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          'PERIZINAN AKSES',
                          style: TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: AppTheme.neonCyan.withOpacity(0.3), blurRadius: 8)
                            ]
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                        const SizedBox(height: 8),
                        const Text(
                          'Konfigurasi Perangkat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
                        const SizedBox(height: 12),
                        Text(
                          'Aktifkan perizinan berikut agar Chek Mobilku dapat terhubung dengan OBD-II dan asisten suara AI dapat berjalan normal.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                        
                        const SizedBox(height: 32),
                        
                        Expanded(
                          child: ListView(
                            children: [
                              _PermissionTile(
                                icon: Icons.bluetooth_rounded,
                                title: 'Bluetooth & Perangkat Sekitar',
                                subtitle: 'Koneksi nirkabel ke adaptor OBD-II ELM327',
                                isGranted: _bluetoothGranted,
                                onTap: _requestBluetooth,
                              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05),
                              const SizedBox(height: 14),
                              _PermissionTile(
                                icon: Icons.my_location_rounded,
                                title: 'Lokasi Presisi',
                                subtitle: 'Diperlukan untuk memindai perangkat Bluetooth terdekat',
                                isGranted: _locationGranted,
                                onTap: _requestLocation,
                              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05),
                              const SizedBox(height: 14),
                              _PermissionTile(
                                icon: FontAwesomeIcons.microphone,
                                title: 'Mikrofon & Perekam Audio',
                                subtitle: 'Digunakan untuk interaksi suara asisten AI Jazzy',
                                isGranted: _microphoneGranted,
                                onTap: _requestMicrophone,
                              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.05),
                              const SizedBox(height: 14),
                              _PermissionTile(
                                icon: Icons.notifications_active_rounded,
                                title: 'Notifikasi Sistem',
                                subtitle: 'Pengingat otomatis jadwal servis & peringatan kerusakan',
                                isGranted: _notificationGranted,
                                onTap: _requestNotification,
                              ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.05),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: allGranted
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.neonCyan.withOpacity(0.25),
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: allGranted ? AppTheme.neonCyan : AppTheme.darkSurface,
                                    foregroundColor: allGranted ? Colors.black : Colors.white60,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      side: allGranted
                                          ? BorderSide.none
                                          : BorderSide(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _finishOnboarding,
                                  child: Text(
                                    allGranted ? 'MULAI SEKARANG' : 'LEWATI & LANJUTKAN',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                  ),
                                ),
                              ).animate().scale(delay: 800.ms, duration: 400.ms, curve: Curves.elasticOut),
                              const SizedBox(height: 12),
                              const Text(
                                'Anda tetap dapat mengatur perizinan nanti di Setelan HP.',
                                style: TextStyle(color: Colors.white24, fontSize: 11),
                              ).animate().fadeIn(delay: 900.ms),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: isGranted ? AppTheme.neonGreen.withOpacity(0.22) : Colors.white.withOpacity(0.04),
          width: isGranted ? 1.2 : 1,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.01),
                  blurRadius: 12,
                )
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isGranted ? AppTheme.neonGreen.withOpacity(0.08) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isGranted ? AppTheme.neonGreen.withOpacity(0.12) : Colors.transparent,
            ),
          ),
          child: Icon(icon, size: 20, color: isGranted ? AppTheme.neonGreen : Colors.grey),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.3),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isGranted ? AppTheme.neonGreen.withOpacity(0.1) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isGranted ? AppTheme.neonGreen.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Text(
            isGranted ? 'AKTIF' : 'IZINKAN',
            style: TextStyle(
              color: isGranted ? AppTheme.neonGreen : AppTheme.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: isGranted ? null : onTap,
      ),
    );
  }
}

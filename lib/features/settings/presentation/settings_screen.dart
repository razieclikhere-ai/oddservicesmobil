// ────────────────────────────────────────────────────────────────────────────
// features/settings/presentation/settings_screen.dart
// Settings screen — includes notification, OBD auto-connect, language, and Groq API Key
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/database/app_database.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifEnabled = true;
  bool _autoConnectObd = true;
  String _selectedLanguage = 'id';
  String _apiKeySaved = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _autoConnectObd = prefs.getBool('auto_connect_obd') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'id';
      _apiKeySaved = prefs.getString('user_groq_api_key') ?? '';
      _loading = false;
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKeySaved);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Kunci API Groq',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Kunci API Groq Anda (gsk_...) untuk koneksi AI yang stabil, aman, dan bebas dari batasan limit bersama.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'gsk_...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              final prefs = await SharedPreferences.getInstance();
              if (val.isEmpty) {
                await prefs.remove('user_groq_api_key');
              } else {
                await prefs.setString('user_groq_api_key', val);
              }
              setState(() {
                _apiKeySaved = val;
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Notifications ──────────────────────────────────────
                _SectionHeader('Notifikasi'),
                _SettingsCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Pengingat Servis',
                      subtitle: 'Notifikasi otomatis sebelum jadwal servis',
                      value: _notifEnabled,
                      onChanged: (v) async {
                        setState(() => _notifEnabled = v);
                        await _savePref('notif_enabled', v);
                        if (!v) {
                          await NotificationService.cancelAllNotifications();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Koneksi OBD ────────────────────────────────────────
                _SectionHeader('Koneksi OBD'),
                _SettingsCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.bluetooth_outlined,
                      title: 'Auto-Connect OBD',
                      subtitle: 'Otomatis scan adaptor ELM327 saat aplikasi dibuka',
                      value: _autoConnectObd,
                      onChanged: (v) async {
                        setState(() => _autoConnectObd = v);
                        await _savePref('auto_connect_obd', v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Konfigurasi AI ──────────────────────────────────────────
                _SectionHeader('Konfigurasi AI'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.vpn_key_outlined,
                          color: AppTheme.neonCyan),
                      title: const Text('Kunci API Groq',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        _apiKeySaved.isEmpty
                            ? 'Default (Menggunakan Kunci Cadangan)'
                            : '${_apiKeySaved.substring(0, _apiKeySaved.length > 12 ? 12 : _apiKeySaved.length)}... (Ketuk untuk ubah)',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: Colors.grey),
                      onTap: _showApiKeyDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Bahasa ─────────────────────────────────────────────
                _SectionHeader('Bahasa'),
                _SettingsCard(
                  children: [
                    _SelectTile(
                      icon: Icons.language_outlined,
                      title: 'Bahasa Antarmuka',
                      value: _selectedLanguage == 'id'
                          ? 'Bahasa Indonesia'
                          : 'English',
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: AppTheme.darkSurface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (_) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              const Text('Pilih Bahasa',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 12),
                              ListTile(
                                title: const Text('Bahasa Indonesia',
                                    style: TextStyle(color: Colors.white)),
                                leading: const Text('🇮🇩'),
                                onTap: () => Navigator.pop(context, 'id'),
                              ),
                              ListTile(
                                title: const Text('English',
                                    style: TextStyle(color: Colors.white)),
                                leading: const Text('🇺🇸'),
                                onTap: () => Navigator.pop(context, 'en'),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(() => _selectedLanguage = picked);
                          await _savePref('language', picked);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Data ───────────────────────────────────────────────
                _SectionHeader('Data & Privasi'),
                _SettingsCard(
                  children: [
                    _ActionTile(
                      icon: Icons.delete_outline,
                      title: 'Hapus Semua Riwayat Scan',
                      subtitle: 'Hapus semua log OBD dari penyimpanan lokal',
                      iconColor: AppTheme.neonOrange,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.darkSurface,
                            title: const Text(
                              'Hapus Riwayat Scan?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Semua data riwayat scan OBD akan dihapus permanen.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.neonOrange,
                                    foregroundColor: Colors.black),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final activeUuid =
                              ref.read(activeVehicleUuidProvider);
                          await AppDatabase.deleteAllScans(activeUuid);
                          ref.invalidate(scanHistoryProvider);
                          ref.invalidate(recentScansProvider);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Riwayat scan berhasil dihapus'),
                                backgroundColor: AppTheme.neonGreen,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Tentang ────────────────────────────────────────────
                _SectionHeader('Tentang Aplikasi'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _InfoRow('Versi', '1.0.0'),
                      _InfoRow('AI Engine', 'Groq · Llama 3 70B & 8B'),
                      _InfoRow('OBD Protocol', 'ELM327 · ISO 15765-4 (CAN)'),
                      _InfoRow('Database', 'SQLite v3 (sqflite)'),
                      _InfoRow('Minimum Android', 'Android 5.0 (API 21)'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── Reusable Setting Widgets ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: AppTheme.cardRadius,
        border: AppTheme.glassBorder,
      ),
      child: Column(
        children: children
            .map((c) => Column(children: [
                  c,
                  if (c != children.last)
                    Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.04),
                        indent: 56),
                ]))
            .toList(),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.neonCyan),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.neonCyan,
      activeTrackColor: AppTheme.neonCyan.withOpacity(0.2),
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.white10,
    );
  }
}

class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final VoidCallback onTap;

  const _SelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.neonCyan),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

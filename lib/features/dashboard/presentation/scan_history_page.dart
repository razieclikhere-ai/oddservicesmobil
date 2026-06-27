import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({Key? key}) : super(key: key);

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  List<Map<String, dynamic>> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    final list = await AppDatabase.getScans('default-honda-jazz-ge8');
    if (mounted) {
      setState(() {
        _scans = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Hapus Riwayat?', style: TextStyle(color: Colors.white)),
        content: const Text('Semua data scan OBD Anda sebelumnya akan dihapus permanen.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonOrange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await AppDatabase.database;
      await db.delete('obd_scans', where: 'vehicle_uuid = ?', whereArgs: ['default-honda-jazz-ge8']);
      _loadScans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        title: const Text('Semua Riwayat Scan OBD', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.neonOrange),
              onPressed: _clearHistory,
              tooltip: 'Bersihkan Riwayat',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : _scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Riwayat Scan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hubungkan OBD Bluetooth untuk menyimpan data scan pertama Anda.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scans.length,
                  itemBuilder: (context, index) {
                    final scan = _scans[index];
                    final date = DateTime.tryParse(scan['scan_date'] as String? ?? '') ?? DateTime.now();
                    final timeStr = "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    final isError = (scan['dtc_codes'] as String? ?? '').isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isError ? AppTheme.neonOrange.withOpacity(0.3) : Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(timeStr, style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isError ? AppTheme.neonOrange : AppTheme.neonGreen).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isError ? 'Ada Error' : 'Sehat',
                                  style: TextStyle(
                                    color: isError ? AppTheme.neonOrange : AppTheme.neonGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          
                          // Grid of values
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildValueColumn('RPM', '${(scan['rpm'] as num?)?.toStringAsFixed(0) ?? "-"} rpm'),
                              _buildValueColumn('Kecepatan', '${(scan['speed'] as num?)?.toStringAsFixed(0) ?? "-"} km/h'),
                              _buildValueColumn('Radiator', '${(scan['coolant_temp'] as num?)?.toStringAsFixed(1) ?? "-"} °C'),
                              _buildValueColumn('Aki', '${(scan['battery_voltage'] as num?)?.toStringAsFixed(2) ?? "-"} V'),
                            ],
                          ),
                          
                          if (isError) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.neonOrange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_rounded, color: AppTheme.neonOrange, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kode DTC: ${scan['dtc_codes']}',
                                    style: const TextStyle(color: AppTheme.neonOrange, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.map_outlined, size: 13, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text('Mileage: ${scan['mileage']} km', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              const Spacer(),
                              Text(scan['notes'] ?? '', style: const TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildValueColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

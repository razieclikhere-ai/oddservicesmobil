import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/ai_prediction_service.dart';

class ServiceLogsPage extends StatefulWidget {
  const ServiceLogsPage({Key? key}) : super(key: key);

  @override
  State<ServiceLogsPage> createState() => _ServiceLogsPageState();
}

class _ServiceLogsPageState extends State<ServiceLogsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final list = await AppDatabase.getServiceLogs('default-honda-jazz-ge8');
    if (mounted) {
      setState(() {
        _logs = list;
        _isLoading = false;
      });
    }
  }

  void _showFormDialog([Map<String, dynamic>? logToEdit]) {
    final isEdit = logToEdit != null;
    final uuid = isEdit ? logToEdit['uuid'] as String : const Uuid().v4();
    
    DateTime selectedDate = isEdit 
        ? (DateTime.tryParse(logToEdit['service_date'] as String? ?? '') ?? DateTime.now())
        : DateTime.now();
        
    final typeController = TextEditingController(text: isEdit ? logToEdit['service_type'] : 'Ganti Oli Mesin');
    final brandController = TextEditingController(text: isEdit ? logToEdit['oil_brand'] : '');
    final mileageController = TextEditingController(text: isEdit ? logToEdit['current_mileage']?.toString() : '150000');
    final nextTargetController = TextEditingController(text: isEdit ? logToEdit['next_target_mileage']?.toString() : '160000');
    final notesController = TextEditingController(text: isEdit ? logToEdit['notes'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Ubah Catatan Servis' : 'Catat Servis Baru',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.neonOrange),
                        onPressed: () async {
                          await AppDatabase.deleteServiceLog(uuid);
                          if (mounted) {
                            Navigator.pop(context);
                            _loadLogs();
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Date picker trigger
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.neonCyan,
                            onPrimary: Colors.black,
                            surface: AppTheme.darkSurface,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tanggal Servis', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(color: AppTheme.neonCyan, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                _buildFieldLabel('Tipe Servis'),
                _buildTextField(typeController, 'Contoh: Ganti Oli Mesin, Servis Rem...'),
                
                const SizedBox(height: 12),
                _buildFieldLabel('Merek Oli / Suku Cadang'),
                _buildTextField(brandController, 'Contoh: Shell Helix HX8, Castrol, dll.'),
                
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Kilometer Tercatat'),
                          _buildTextField(mileageController, 'KM saat ini', TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('KM Pengisian Berikutnya'),
                          _buildTextField(nextTargetController, 'Target KM', TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                _buildFieldLabel('Catatan Tambahan'),
                _buildTextField(notesController, 'Tulis catatan servis tambahan di sini...', TextInputType.text, 3),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final currentMil = int.tryParse(mileageController.text) ?? 150000;
                      final nextMil = int.tryParse(nextTargetController.text) ?? 160000;
                      
                      final newLog = {
                        'uuid': uuid,
                        'vehicle_uuid': 'default-honda-jazz-ge8',
                        'service_date': selectedDate.toIso8601String(),
                        'service_type': typeController.text.trim(),
                        'oil_brand': brandController.text.trim(),
                        'current_mileage': currentMil,
                        'next_target_mileage': nextMil,
                        'cost': 0,
                        'notes': notesController.text.trim(),
                        'created_at': isEdit ? (logToEdit['created_at'] ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String(),
                      };

                      if (isEdit) {
                        await AppDatabase.updateServiceLog(newLog);
                      } else {
                        await AppDatabase.insertServiceLog(newLog);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _loadLogs();
                        
                        // Show loading indicator or trigger background AI prediction
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('🤖 Sahabat AI Jazzy sedang menganalisis jadwal servis berikutnya...'),
                            backgroundColor: AppTheme.neonCyan,
                            duration: Duration(seconds: 4),
                          ),
                        );
                        
                        // Trigger AI Analysis in background
                        await AiPredictionService.analyzeServiceLogAndSchedule(
                          vehicleUuid: 'default-honda-jazz-ge8',
                          serviceType: typeController.text.trim(),
                          oilBrand: brandController.text.trim(),
                          currentMileage: currentMil,
                          nextTargetMileage: nextMil,
                          serviceDate: selectedDate,
                        );
                      }
                    },
                    child: const Text('Simpan & Analisis AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, [TextInputType type = TextInputType.text, int lines = 1]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: lines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
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
        title: const Text('Catatan & Riwayat Servis', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.neonCyan),
            onPressed: () => _showFormDialog(),
            tooltip: 'Catat Servis Baru',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Catatan Servis',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Catat riwayat ganti oli, servis rem, atau servis AC Anda. AI akan menganalisis jadwal berikutnya dan mengingatkan Anda.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonCyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _showFormDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Catat Servis Pertama', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.tryParse(log['service_date'] as String? ?? '') ?? DateTime.now();
                    final dateStr = "${date.day}/${date.month}/${date.year}";

                    return GestureDetector(
                      onTap: () => _showFormDialog(log),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log['service_type'] ?? 'Servis Berkala',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                Text(dateStr, style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if ((log['oil_brand'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.opacity_rounded, size: 13, color: AppTheme.neonCyan),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Oli/Sparepart: ${log['oil_brand']}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            
                            // Mileage details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildValueColumn('KM Saat Servis', '${log['current_mileage']} km'),
                                _buildValueColumn('KM Servis Berikutnya', '${log['next_target_mileage']} km'),
                              ],
                            ),
                            
                            if ((log['notes'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  log['notes'] ?? '',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Ketuk untuk ubah / edit data', style: TextStyle(color: Colors.white24, fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/service_logs_page.dart
// CRUD log page for service events — Riverpod activeVehicleProvider integration
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/ai_prediction_service.dart';

class ServiceLogsPage extends ConsumerStatefulWidget {
  const ServiceLogsPage({super.key});

  @override
  ConsumerState<ServiceLogsPage> createState() => _ServiceLogsPageState();
}

class _ServiceLogsPageState extends ConsumerState<ServiceLogsPage> {
  @override
  Widget build(BuildContext context) {
    final activeUuid = ref.watch(activeVehicleUuidProvider);
    final logsAsync = ref.watch(serviceLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        title: const Text(
          'Catatan & Riwayat Servis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppTheme.neonCyan),
            onPressed: () => _showFormDialog(context, activeUuid),
            tooltip: 'Catat Servis Baru',
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.neonCyan),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.neonOrange),
              const SizedBox(height: 12),
              Text('Gagal memuat catatan: $e',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(serviceLogsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (logs) => logs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.library_books_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Catatan Servis',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Catat riwayat ganti oli, aki, rem, dll. AI akan menganalisis jadwal berikutnya secara otomatis.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showFormDialog(context, activeUuid),
                      icon: const Icon(Icons.add),
                      label: const Text('Catat Servis Pertama',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: AppTheme.neonCyan,
                onRefresh: () async => ref.invalidate(serviceLogsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date =
                        DateTime.tryParse(log['service_date'] as String? ?? '') ??
                            DateTime.now();
                    final dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(date);
                    final cost = log['cost'] as int? ?? 0;

                    return GestureDetector(
                      onTap: () =>
                          _showFormDialog(context, activeUuid, log),
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
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(dateStr,
                                    style: const TextStyle(
                                        color: AppTheme.neonCyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if ((log['oil_brand'] as String? ?? '').isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.opacity_rounded,
                                        size: 13, color: AppTheme.neonCyan),
                                    const SizedBox(width: 6),
                                    Text('Suku Cadang/Oli: ${log['oil_brand']}',
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12)),
                                  ]),
                                if (cost > 0)
                                  Text(
                                    NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: 'Rp ',
                                            decimalDigits: 0)
                                        .format(cost),
                                    style: const TextStyle(
                                        color: AppTheme.neonGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),

                            // Mileage details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildValueColumn(
                                    'KM Saat Servis', '${log['current_mileage']} km'),
                                _buildValueColumn('KM Servis Berikutnya',
                                    '${log['next_target_mileage']} km'),
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
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Ketuk untuk ubah / hapus data',
                                    style: TextStyle(
                                        color: Colors.white24, fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildValueColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showFormDialog(BuildContext context, String vehicleUuid,
      [Map<String, dynamic>? logToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ServiceLogForm(
        vehicleUuid: vehicleUuid,
        logToEdit: logToEdit,
        onSaved: () {
          ref.invalidate(serviceLogsProvider);
          ref.invalidate(schedulesProvider);
        },
      ),
    );
  }
}

// ── Service Log Form Modal Bottom Sheet ───────────────────────────────────────
class _ServiceLogForm extends ConsumerStatefulWidget {
  final String vehicleUuid;
  final Map<String, dynamic>? logToEdit;
  final VoidCallback onSaved;

  const _ServiceLogForm({
    required this.vehicleUuid,
    required this.onSaved,
    this.logToEdit,
  });

  @override
  ConsumerState<_ServiceLogForm> createState() => _ServiceLogFormState();
}

class _ServiceLogFormState extends ConsumerState<_ServiceLogForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _typeCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _mileageCtrl;
  late TextEditingController _nextTargetCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.logToEdit;
    final isEdit = log != null;

    _selectedDate = isEdit
        ? (DateTime.tryParse(log['service_date'] as String? ?? '') ?? DateTime.now())
        : DateTime.now();

    _typeCtrl = TextEditingController(
        text: isEdit ? log['service_type'] : 'Ganti Oli Mesin');
    _brandCtrl = TextEditingController(text: isEdit ? log['oil_brand'] : '');
    _mileageCtrl = TextEditingController(
        text: isEdit ? log['current_mileage']?.toString() : '150000');
    _nextTargetCtrl = TextEditingController(
        text: isEdit ? log['next_target_mileage']?.toString() : '160000');
    _costCtrl = TextEditingController(
        text: isEdit ? log['cost']?.toString() : '0');
    _notesCtrl = TextEditingController(text: isEdit ? log['notes'] : '');
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _brandCtrl.dispose();
    _mileageCtrl.dispose();
    _nextTargetCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.logToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
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
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: AppTheme.neonOrange),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.darkSurface,
                            title: const Text('Hapus Catatan?',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                                'Catatan servis ini akan dihapus permanen.',
                                style: TextStyle(color: Colors.grey)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.neonOrange,
                                    foregroundColor: Colors.black),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await AppDatabase.deleteServiceLog(
                              widget.logToEdit!['uuid']);
                          widget.onSaved();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Date picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
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
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tanggal Servis',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                        style: const TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              _buildFieldLabel('Tipe Servis'),
              _buildTextFormField(
                  _typeCtrl, 'Contoh: Ganti Oli Mesin, Servis Rem...',
                  validator: (v) =>
                      v?.isEmpty == true ? 'Tipe servis wajib diisi' : null),

              const SizedBox(height: 12),
              _buildFieldLabel('Merek Oli / Suku Cadang'),
              _buildTextFormField(_brandCtrl, 'Contoh: Shell Helix HX8, Castrol...'),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Kilometer Odometer'),
                        _buildTextFormField(_mileageCtrl, 'KM saat ini',
                            type: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'KM wajib';
                              if (int.tryParse(v!) == null) return 'Angka saja';
                              return null;
                            }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('KM Berikutnya'),
                        _buildTextFormField(_nextTargetCtrl, 'Target KM',
                            type: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Target KM wajib';
                              if (int.tryParse(v!) == null) return 'Angka saja';
                              return null;
                            }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              _buildFieldLabel('Biaya Servis (Rp)'),
              _buildTextFormField(_costCtrl, 'Contoh: 350000',
                  type: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                      return 'Angka saja';
                    }
                    return null;
                  }),

              const SizedBox(height: 12),
              _buildFieldLabel('Catatan Tambahan'),
              _buildTextFormField(_notesCtrl, 'Keterangan tambahan...',
                  lines: 3),

              const SizedBox(height: 24),
              if (_isSaving)
                const Center(
                    child: CircularProgressIndicator(color: AppTheme.neonCyan))
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState?.validate() == true) {
                        setState(() => _isSaving = true);
                        final currentMil = int.parse(_mileageCtrl.text);
                        final nextMil = int.parse(_nextTargetCtrl.text);
                        final cost = int.tryParse(_costCtrl.text) ?? 0;
                        final uuid = isEdit
                            ? widget.logToEdit!['uuid'] as String
                            : const Uuid().v4();

                        final logData = {
                          'uuid': uuid,
                          'vehicle_uuid': widget.vehicleUuid,
                          'service_date': _selectedDate.toIso8601String(),
                          'service_type': _typeCtrl.text.trim(),
                          'oil_brand': _brandCtrl.text.trim(),
                          'current_mileage': currentMil,
                          'next_target_mileage': nextMil,
                          'cost': cost,
                          'notes': _notesCtrl.text.trim(),
                          'created_at': isEdit
                              ? (widget.logToEdit!['created_at'] ??
                                  DateTime.now().toIso8601String())
                              : DateTime.now().toIso8601String(),
                        };

                        if (isEdit) {
                          await AppDatabase.updateServiceLog(logData);
                        } else {
                          await AppDatabase.insertServiceLog(logData);
                        }

                        // Update current mileage in vehicle table
                        await AppDatabase.updateVehicleMileage(
                            widget.vehicleUuid, currentMil);

                        widget.onSaved();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  '🤖 Jazzy sedang menganalisis jadwal servis berikutnya...'),
                              backgroundColor: AppTheme.neonCyan,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }

                        // Trigger AI Analysis in background
                        try {
                          await AiPredictionService.analyzeServiceLogAndSchedule(
                            vehicleUuid: widget.vehicleUuid,
                            serviceType: _typeCtrl.text.trim(),
                            oilBrand: _brandCtrl.text.trim(),
                            currentMileage: currentMil,
                            nextTargetMileage: nextMil,
                            serviceDate: _selectedDate,
                          );
                        } catch (_) {}

                        // Auto-refresh schedules provider
                        widget.onSaved();
                      }
                    },
                    child: const Text('Simpan & Analisis AI',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
            ],
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
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
    int lines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: lines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.neonCyan),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.neonOrange),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.neonOrange),
        ),
      ),
    );
  }
}

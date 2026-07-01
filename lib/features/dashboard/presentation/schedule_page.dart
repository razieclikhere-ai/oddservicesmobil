// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/schedule_page.dart
// Service schedule tab — uses Riverpod provider, supports edit & delete
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/safe_format.dart';
import 'service_logs_page.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(selectedServisTabProvider);
    final activeUuid = ref.watch(activeVehicleUuidProvider);
    final schedulesAsync = ref.watch(schedulesProvider);
    final logsAsync = ref.watch(serviceLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Jadwal & Catatan Servis',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (activeTab == 0)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
              onPressed: () => ref.invalidate(schedulesProvider),
              tooltip: 'Refresh',
            ),
          if (activeTab == 1)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.neonCyan),
              onPressed: () => _showFormDialog(context, ref, activeUuid),
              tooltip: 'Catat Servis Baru',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSegmentedControl(context, ref, activeTab),
          Expanded(
            child: activeTab == 0
                ? _buildJadwalView(context, ref, schedulesAsync)
                : _buildRiwayatView(context, ref, logsAsync, activeUuid),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, WidgetRef ref, int activeTab) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Estimasi Jadwal (AI)',
            isActive: activeTab == 0,
            onTap: () => ref.read(selectedServisTabProvider.notifier).state = 0,
          ),
          _SegmentButton(
            label: 'Riwayat Catatan',
            isActive: activeTab == 1,
            onTap: () => ref.read(selectedServisTabProvider.notifier).state = 1,
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalView(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> schedulesAsync) {
    return schedulesAsync.when(
      loading: () => _buildSkeletonLoader(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.neonOrange),
            const SizedBox(height: 12),
            Text('Gagal memuat jadwal: $e', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(schedulesProvider),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan, foregroundColor: Colors.black),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (schedules) => schedules.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppTheme.neonCyan,
              onRefresh: () async => ref.invalidate(schedulesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.length,
                itemBuilder: (_, i) => _ScheduleCard(
                  schedule: schedules[i],
                  index: i,
                ),
              ),
            ),
    );
  }

  Widget _buildRiwayatView(
      BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> logsAsync, String activeUuid) {
    return logsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.neonCyan),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.neonOrange),
            const SizedBox(height: 12),
            Text('Gagal memuat catatan: $e', style: const TextStyle(color: Colors.white70)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showFormDialog(context, ref, activeUuid),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat Servis Pertama', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final date = DateTime.tryParse(log['service_date'] as String? ?? '') ?? DateTime.now();
                  final dateStr = SafeFormat.date(date);
                  final cost = log['cost'] as int? ?? 0;

                  return GestureDetector(
                    onTap: () => _showFormDialog(context, ref, activeUuid, log),
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
                              Expanded(
                                child: Text(
                                  log['service_type'] ?? 'Servis Berkala',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if ((log['oil_brand'] as String? ?? '').isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.opacity_rounded, size: 13, color: AppTheme.neonCyan),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Suku Cadang/Oli: ${log['oil_brand']}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (cost > 0)
                                Text(
                                  SafeFormat.currency(cost),
                                  style: const TextStyle(color: AppTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),

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
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Ketuk untuk ubah / hapus data', style: TextStyle(color: Colors.white24, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showFormDialog(BuildContext context, WidgetRef ref, String vehicleUuid, [Map<String, dynamic>? logToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ServiceLogForm(
        vehicleUuid: vehicleUuid,
        logToEdit: logToEdit,
        onSaved: () {
          ref.invalidate(serviceLogsProvider);
          ref.invalidate(schedulesProvider);
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(18),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.04)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 72, color: Colors.grey[700]),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Jadwal Servis',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hubungkan OBD-II atau catat servis di tab Catatan — AI akan menganalisis dan membuat jadwal otomatis.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _SegmentButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.neonCyan : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Schedule Card ─────────────────────────────────────────────────────────────
class _ScheduleCard extends ConsumerWidget {
  final Map<String, dynamic> schedule;
  final int index;
  const _ScheduleCard({required this.schedule, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextDateStr = schedule['next_predicted_date'] as String? ?? '';
    final nextDate = DateTime.tryParse(nextDateStr);
    final daysLeft = nextDate != null
        ? nextDate.difference(DateTime.now()).inDays
        : null;

    final Color urgencyColor;
    final String urgencyLabel;

    if (daysLeft == null) {
      urgencyColor = Colors.grey;
      urgencyLabel = 'Tidak Diketahui';
    } else if (daysLeft <= 0) {
      urgencyColor = AppTheme.neonOrange;
      urgencyLabel = 'TERLAMBAT!';
    } else if (daysLeft <= 14) {
      urgencyColor = AppTheme.neonYellow;
      urgencyLabel = '$daysLeft hari lagi';
    } else if (daysLeft <= 30) {
      urgencyColor = AppTheme.neonCyan;
      urgencyLabel = '$daysLeft hari lagi';
    } else {
      urgencyColor = AppTheme.neonGreen;
      urgencyLabel = '$daysLeft hari lagi';
    }

    final nextMil =
        schedule['next_predicted_mileage'] as int? ?? 0;
    final lastMil =
        schedule['last_service_mileage'] as int? ?? 0;
    final intervalKm =
        schedule['interval_mileage'] as int? ?? 10000;
    final description =
        schedule['description'] as String? ?? '';
    final dateFormatted = nextDate != null
        ? SafeFormat.date(nextDate)
        : '-';

    return GestureDetector(
      onTap: () => _showEditScheduleDialog(context, ref, schedule),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: urgencyColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: urgencyColor.withOpacity(0.04),
              blurRadius: 16,
            )
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    schedule['service_name'] as String? ??
                        'Servis Berkala',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    urgencyLabel,
                    style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + KM row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InfoChip(
                          icon: Icons.calendar_today,
                          label: 'Target Tanggal',
                          value: dateFormatted,
                          color: urgencyColor),
                      _InfoChip(
                          icon: Icons.speed,
                          label: 'Target KM',
                          value: '$nextMil km',
                          color: AppTheme.neonCyan),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress bar (mileage)
                  if (intervalKm > 0 && lastMil > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progres: $lastMil → $nextMil km',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                        Text(
                          'Interval: ${intervalKm}km',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: 1.0, // Shown as full (next target)
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor:
                          Colors.white.withOpacity(0.05),
                      valueColor:
                          AlwaysStoppedAnimation(urgencyColor),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // AI description
                  if (description.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('🤖 ',
                              style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              description,
                              style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Ketuk untuk ubah / hapus jadwal',
                          style: TextStyle(color: Colors.white24, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08);
  }

  void _showEditScheduleDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditScheduleForm(
        schedule: schedule,
        onSaved: () {
          ref.invalidate(schedulesProvider);
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 3),
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ]),
      ],
    );
  }
}

// ── Edit Schedule Form Bottom Sheet ──────────────────────────────────────────
class _EditScheduleForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onSaved;

  const _EditScheduleForm({
    required this.schedule,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditScheduleForm> createState() => _EditScheduleFormState();
}

class _EditScheduleFormState extends ConsumerState<_EditScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _intervalKmCtrl;
  late TextEditingController _intervalMonthsCtrl;
  late TextEditingController _lastKmCtrl;
  late DateTime _lastDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _nameCtrl = TextEditingController(text: s['service_name'] as String? ?? '');
    _descCtrl = TextEditingController(text: s['description'] as String? ?? '');
    _intervalKmCtrl = TextEditingController(text: (s['interval_mileage'] as int? ?? 10000).toString());
    _intervalMonthsCtrl = TextEditingController(text: (s['interval_months'] as int? ?? 6).toString());
    _lastKmCtrl = TextEditingController(text: (s['last_service_mileage'] as int? ?? 0).toString());
    _lastDate = DateTime.tryParse(s['last_service_date'] as String? ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _intervalKmCtrl.dispose();
    _intervalMonthsCtrl.dispose();
    _lastKmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Ubah Jadwal Servis',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: AppTheme.neonOrange),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.darkSurface,
                          title: const Text('Hapus Jadwal?',
                              style: TextStyle(color: Colors.white)),
                          content: const Text(
                              'Jadwal servis ini akan dihapus permanen.',
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
                        await AppDatabase.deleteSchedule(
                            widget.schedule['uuid']);
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
                    initialDate: _lastDate,
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
                    setState(() => _lastDate = picked);
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
                      const Text('Tanggal Servis Terakhir',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        "${_lastDate.day}/${_lastDate.month}/${_lastDate.year}",
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
              _buildFieldLabel('Nama Servis'),
              _buildTextFormField(
                  _nameCtrl, 'Contoh: Ganti Oli Mesin, Servis Rem...',
                  validator: (v) =>
                      v?.isEmpty == true ? 'Nama servis wajib diisi' : null),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Interval Kilometer'),
                        _buildTextFormField(_intervalKmCtrl, '10000',
                            type: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Wajib';
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
                        _buildFieldLabel('Interval Bulan'),
                        _buildTextFormField(_intervalMonthsCtrl, '6',
                            type: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Wajib';
                              if (int.tryParse(v!) == null) return 'Angka saja';
                              return null;
                            }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              _buildFieldLabel('Kilometer Terakhir Ganti'),
              _buildTextFormField(_lastKmCtrl, 'KM Terakhir',
                  type: TextInputType.number,
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Wajib';
                    if (int.tryParse(v!) == null) return 'Angka saja';
                    return null;
                  }),

              const SizedBox(height: 12),
              _buildFieldLabel('Keterangan / Rekomendasi'),
              _buildTextFormField(_descCtrl, 'Keterangan tambahan...',
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
                        final km = int.parse(_intervalKmCtrl.text);
                        final months = int.parse(_intervalMonthsCtrl.text);
                        final lastKm = int.parse(_lastKmCtrl.text);

                        final updated = {
                          'uuid': widget.schedule['uuid'],
                          'vehicle_uuid': widget.schedule['vehicle_uuid'],
                          'service_name': _nameCtrl.text.trim(),
                          'description': _descCtrl.text.trim(),
                          'interval_mileage': km,
                          'interval_months': months,
                          'last_service_mileage': lastKm,
                          'last_service_date': _lastDate.toIso8601String(),
                          'next_predicted_date': _lastDate.add(Duration(days: months * 30)).toIso8601String(),
                          'next_predicted_mileage': lastKm + km,
                          'is_enabled': widget.schedule['is_enabled'] ?? 1,
                        };

                        await AppDatabase.insertOrUpdateSchedule(updated);
                        widget.onSaved();

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('Simpan Jadwal',
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

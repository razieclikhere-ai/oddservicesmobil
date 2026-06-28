// ────────────────────────────────────────────────────────────────────────────
// features/dashboard/presentation/schedule_page.dart
// Service schedule tab — uses Riverpod provider, no hardcoded UUID
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Jadwal Servis',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
            onPressed: () => ref.invalidate(schedulesProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => _buildSkeletonLoader(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.neonOrange),
              const SizedBox(height: 12),
              Text('Gagal memuat jadwal: $e',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(schedulesProvider),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonCyan,
                    foregroundColor: Colors.black),
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

// ── Schedule Card ─────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final int index;
  const _ScheduleCard({required this.schedule, required this.index});

  @override
  Widget build(BuildContext context) {
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
        ? DateFormat('dd MMM yyyy', 'id_ID').format(nextDate)
        : '-';

    return Container(
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
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08);
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

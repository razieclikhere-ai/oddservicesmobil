// ────────────────────────────────────────────────────────────────────────────
// features/vehicles/presentation/vehicles_screen.dart
// Vehicle management — Riverpod activeVehicleProvider + safe parsing
// ────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/obd_bluetooth_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// Singleton Dio for this screen
final _dio = Dio(BaseOptions(
  baseUrl: 'https://api.groq.com/openai/v1',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 30),
));

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final activeUuid = ref.watch(activeVehicleUuidProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text(
          'Manajemen Kendaraan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: vehiclesAsync.when(
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
              Text('Gagal memuat kendaraan: $e',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(vehiclesProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (vehicles) => vehicles.isEmpty
            ? _buildEmptyState()
            : _buildVehicleList(vehicles, activeUuid),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Tambah Kendaraan',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddVehicleDialog() {
    final formKey = GlobalKey<FormState>();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final engineCtrl = TextEditingController();
    final mileageCtrl = TextEditingController();
    String fuelType = 'Petrol';
    String transmission = 'Automatic';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tambah Kendaraan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isSaving)
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                                color: AppTheme.neonCyan),
                            const SizedBox(height: 16),
                            Text(
                              'AI sedang menyusun jadwal servis berkala...',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Brand + Model
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: brandCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Merek (contoh: Toyota)'),
                          validator: (v) => v?.isEmpty == true
                              ? 'Merek wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: modelCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Model (contoh: Avanza)'),
                          validator: (v) => v?.isEmpty == true
                              ? 'Model wajib diisi'
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Year + Engine
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: yearCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Tahun (contoh: 2020)'),
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Tahun wajib diisi';
                            if (int.tryParse(v!) == null) return 'Angka saja';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: engineCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Mesin (contoh: 1.3L VVT-i)'),
                          validator: (v) => v?.isEmpty == true
                              ? 'Mesin wajib diisi'
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Mileage
                    TextFormField(
                      controller: mileageCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecor('Odometer Saat Ini (km)'),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'KM wajib diisi';
                        if (int.tryParse(v!) == null) return 'Angka saja';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fuel + Transmission dropdowns
                    Row(children: [
                      const Text('BBM: ',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: fuelType,
                        dropdownColor: AppTheme.darkSurface,
                        style: const TextStyle(color: Colors.white),
                        items: ['Petrol', 'Diesel', 'Hybrid', 'Electric']
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModal(() => fuelType = v);
                        },
                      ),
                      const Spacer(),
                      const Text('Transmisi: ',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: transmission,
                        dropdownColor: AppTheme.darkSurface,
                        style: const TextStyle(color: Colors.white),
                        items: ['Manual', 'Automatic']
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModal(() => transmission = v);
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonCyan,
                          foregroundColor: Colors.black,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState?.validate() == true) {
                            setModal(() => isSaving = true);
                            await _saveVehicleWithAi(
                              brand: brandCtrl.text.trim(),
                              model: modelCtrl.text.trim(),
                              year: int.parse(yearCtrl.text.trim()),
                              engine: engineCtrl.text.trim(),
                              mileage: int.parse(mileageCtrl.text.trim()),
                              fuel: fuelType,
                              trans: transmission,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            ref.invalidate(vehiclesProvider);
                          }
                        },
                        child: const Text('Simpan & Analisis AI',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: AppTheme.darkSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.05)),
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
      );

  Future<void> _saveVehicleWithAi({
    required String brand,
    required String model,
    required int year,
    required String engine,
    required int mileage,
    required String fuel,
    required String trans,
  }) async {
    final vehicleUuid = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    await AppDatabase.insertVehicle({
      'uuid': vehicleUuid,
      'name': '$brand $model',
      'brand': brand,
      'model': model,
      'year': year,
      'engine_type': engine,
      'fuel_type': fuel,
      'transmission_type': trans,
      'current_mileage': mileage,
      'created_at': now,
      'updated_at': now,
      'is_active': 1,
    });

    const apiKey =
        String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

    if (apiKey.isEmpty) {
      _log.w('VehiclesScreen: GROQ_API_KEY not set — using local fallback schedules');
      await _seedLocalSchedules(vehicleUuid, mileage);
      return;
    }

    try {
      final resp = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-70b-8192',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Buatkan daftar jadwal servis/maintenance rutin standar berdasarkan spesifikasi mobil. Kembalikan HANYA JSON ARRAY valid. Setiap objek: {"service_name":string, "interval_mileage":int, "interval_months":int, "description":string}',
            },
            {
              'role': 'user',
              'content':
                  'Merek: $brand\nModel: $model\nTahun: $year\nMesin: $engine\nBBM: $fuel\nTransmisi: $trans\nOdometer: $mileage km',
            },
          ],
          'temperature': 0.3,
        },
      );

      final raw =
          resp.data['choices'][0]['message']['content'] as String;
      final clean =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> schedules = jsonDecode(clean);
      final nowDate = DateTime.now();

      for (final s in schedules) {
        final serviceName =
            s['service_name'] as String? ?? 'Servis Berkala';
        final intervalMil =
            (s['interval_mileage'] as num?)?.toInt() ?? 10000;
        final intervalMon =
            (s['interval_months'] as num?)?.toInt() ?? 6;
        final desc = s['description'] as String? ?? '';

        await AppDatabase.insertOrUpdateSchedule({
          'uuid':
              '${vehicleUuid}_${serviceName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          'vehicle_uuid': vehicleUuid,
          'service_name': serviceName,
          'description': desc,
          'interval_mileage': intervalMil,
          'interval_months': intervalMon,
          'last_service_mileage': mileage,
          'last_service_date': nowDate.toIso8601String(),
          'next_predicted_date':
              nowDate.add(Duration(days: intervalMon * 30)).toIso8601String(),
          'next_predicted_mileage': mileage + intervalMil,
          'is_enabled': 1,
        });
      }
      _log.i('VehiclesScreen: ${schedules.length} schedules created for $vehicleUuid');
    } on DioException catch (e) {
      _log.w('VehiclesScreen AI call DioError: ${e.message}');
      await _seedLocalSchedules(vehicleUuid, mileage);
    } catch (e, st) {
      _log.e('VehiclesScreen _saveVehicleWithAi error', error: e, stackTrace: st);
      await _seedLocalSchedules(vehicleUuid, mileage);
    }
  }

  Future<void> _seedLocalSchedules(
      String vehicleUuid, int mileage) async {
    final now = DateTime.now();
    final defaults = [
      ('Ganti Oli Mesin', 10000, 6),
      ('Filter Udara', 20000, 12),
      ('Busi', 40000, 24),
      ('Minyak Rem', 40000, 24),
    ];
    for (final (name, km, months) in defaults) {
      await AppDatabase.insertOrUpdateSchedule({
        'uuid':
            '${vehicleUuid}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        'vehicle_uuid': vehicleUuid,
        'service_name': name,
        'description':
            'Jadwal standar lokal untuk $name.',
        'interval_mileage': km,
        'interval_months': months,
        'last_service_mileage': mileage,
        'last_service_date': now.toIso8601String(),
        'next_predicted_date':
            now.add(Duration(days: months * 30)).toIso8601String(),
        'next_predicted_mileage': mileage + km,
        'is_enabled': 1,
      });
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.car, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Belum ada kendaraan terdaftar',
              style: TextStyle(
                  color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tambahkan mobil Anda — AI akan menyusun jadwal servis berkala.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList(
      List<Map<String, dynamic>> vehicles, String activeUuid) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final v = vehicles[index];
        final name = v['name'] as String? ?? '-';
        final year = v['year'] as int? ?? 0;
        final engine = v['engine_type'] as String? ?? '-';
        final trans = v['transmission_type'] as String? ?? '-';
        final fuel = v['fuel_type'] as String? ?? '-';
        final mileage = v['current_mileage'] as int? ?? 0;
        final uuid = v['uuid'] as String? ?? '';
        final isActive = uuid == activeUuid;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppTheme.neonCyan.withOpacity(0.3)
                  : Colors.white.withOpacity(0.04),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(FontAwesomeIcons.car,
                        color: AppTheme.neonCyan, size: 18),
                    const SizedBox(width: 12),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ]),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('AKTIF',
                          style: TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$year · $engine · $trans · $fuel',
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.speed,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('$mileage km',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isActive)
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(activeVehicleProvider.notifier)
                            .setActive(uuid);
                        // Sync OBD service
                        ObdBluetoothService.instance.activeVehicleUuid = uuid;
                        ObdBluetoothService.instance.activeVehicleName = name;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$name dijadikan kendaraan aktif'),
                              backgroundColor: AppTheme.neonGreen,
                            ),
                          );
                        }
                      },
                      child: const Text('Jadikan Aktif',
                          style:
                              TextStyle(color: AppTheme.neonCyan)),
                    ),
                  if (uuid != 'default-honda-jazz-ge8') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.neonOrange),
                      tooltip: 'Hapus kendaraan',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.darkSurface,
                            title: Text('Hapus $name?',
                                style: const TextStyle(
                                    color: Colors.white)),
                            content: const Text(
                                'Data kendaraan, jadwal, dan scan akan dihapus.',
                                style: TextStyle(
                                    color: Colors.grey)),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.neonOrange,
                                    foregroundColor: Colors.black),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await AppDatabase.deleteVehicle(uuid);
                          ref.invalidate(vehiclesProvider);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 350.ms).slideY(begin: 0.06);
      },
    );
  }
}

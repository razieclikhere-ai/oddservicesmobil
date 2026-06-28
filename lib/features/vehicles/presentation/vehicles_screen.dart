import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({Key? key}) : super(key: key);

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  String _activeVehicleUuid = 'default-honda-jazz-ge8';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    final list = await AppDatabase.getVehicles();
    setState(() {
      _vehicles = list;
      _isLoading = false;
    });
  }

  void _showAddVehicleDialog() {
    final formKey = GlobalKey<FormState>();
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final engineController = TextEditingController();
    final mileageController = TextEditingController();
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
                          const Text('Tambah Kendaraan Manual',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isSaving)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(color: AppTheme.neonCyan),
                                const SizedBox(height: 16),
                                Text(
                                  'AI sedang menganalisis spesifikasi & menyusun jadwal servis berkala...',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: brandController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Merek (contoh: Toyota)'),
                                validator: (val) => val == null || val.isEmpty ? 'Merek harus diisi' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: modelController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Model (contoh: Avanza)'),
                                validator: (val) => val == null || val.isEmpty ? 'Model harus diisi' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: yearController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Tahun (contoh: 2020)'),
                                validator: (val) => val == null || val.isEmpty ? 'Tahun harus diisi' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: engineController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Mesin (contoh: 1.3L VVT-i)'),
                                validator: (val) => val == null || val.isEmpty ? 'Mesin harus diisi' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: mileageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Odometer Kilometer Saat Ini'),
                          validator: (val) => val == null || val.isEmpty ? 'Kilometer harus diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Bahan Bakar: ', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: fuelType,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(color: Colors.white),
                              items: ['Petrol', 'Diesel', 'Hybrid', 'Electric'].map((type) {
                                return DropdownMenuItem(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => fuelType = val);
                              },
                            ),
                            const Spacer(),
                            const Text('Transmisi: ', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: transmission,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(color: Colors.white),
                              items: ['Manual', 'Automatic'].map((type) {
                                return DropdownMenuItem(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => transmission = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              if (formKey.currentState?.validate() == true) {
                                setModalState(() => isSaving = true);
                                await _saveVehicleWithAi(
                                  brand: brandController.text.trim(),
                                  model: modelController.text.trim(),
                                  year: int.parse(yearController.text.trim()),
                                  engine: engineController.text.trim(),
                                  mileage: int.parse(mileageController.text.trim()),
                                  fuel: fuelType,
                                  trans: transmission,
                                );
                                Navigator.pop(context);
                                _loadVehicles();
                              }
                            },
                            child: const Text('Simpan & Analisis AI', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: AppTheme.darkSurface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.neonCyan),
      ),
    );
  }

  // --- Groq AI Call to Generate Custom Schedules Based on Vehicle Spec ---
  Future<void> _saveVehicleWithAi({
    required String brand,
    required String model,
    required int year,
    required String engine,
    required int mileage,
    required String fuel,
    required String trans,
  }) async {
    final uuidStr = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    // 1. Save vehicle specs locally
    await AppDatabase.insertVehicle({
      'uuid': uuidStr,
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

    final apiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final systemPrompt = '''
Kamu adalah asisten mekanik AI profesional. Berdasarkan spesifikasi teknis mobil yang diinput user, buatkan daftar jadwal servis/maintenance rutin standar yang disarankan untuk tipe mobil tersebut.
Kembalikan respon HANYA dalam format JSON ARRAY yang valid, tanpa teks penjelasan tambahan, pembuka, penutup, atau tanda markdown.

Setiap objek di dalam array harus memiliki properti berikut:
1. "service_name": Nama komponen/servis (contoh: "Ganti Oli Mesin", "Pembersihan Filter Udara", "Inspeksi Sistem Rem", "Ganti Oli Transmisi")
2. "interval_mileage": Interval kilometer standar untuk servis ini (dalam angka saja)
3. "interval_months": Interval bulan standar untuk servis ini (dalam angka saja)
4. "description": Keterangan/rekomendasi singkat mengenai servis ini khusus untuk jenis spesifikasi mesin tersebut.
''';

    final userPrompt = '''
Merek: $brand
Model: $model
Tahun: $year
Mesin: $engine
Bahan Bakar: $fuel
Transmisi: $trans
Odometer Saat Ini: $mileage km
''';

    try {
      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': 'llama3-70b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
        },
      );

      final responseText = response.data['choices'][0]['message']['content'] as String;
      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> schedules = jsonDecode(cleanJson);

      final nowDate = DateTime.now();

      for (final s in schedules) {
        final serviceName = s['service_name'] as String;
        final intervalMil = s['interval_mileage'] as int;
        final intervalMon = s['interval_months'] as int;
        final desc = s['description'] as String;

        await AppDatabase.insertOrUpdateSchedule({
          'uuid': '${uuidStr}_${serviceName.toLowerCase().replaceAll(' ', '_')}',
          'vehicle_uuid': uuidStr,
          'service_name': serviceName,
          'description': desc,
          'interval_mileage': intervalMil,
          'interval_months': intervalMon,
          'last_service_mileage': mileage,
          'last_service_date': nowDate.toIso8601String(),
          'next_predicted_date': nowDate.add(Duration(days: intervalMon * 30)).toIso8601String(),
          'next_predicted_mileage': mileage + intervalMil,
          'is_enabled': 1,
        });
      }
    } catch (e) {
      // Fallback local rules if AI fails
      final nowDate = DateTime.now();
      await AppDatabase.insertOrUpdateSchedule({
        'uuid': '${uuidStr}_oil_change',
        'vehicle_uuid': uuidStr,
        'service_name': 'Ganti Oli Mesin (Lokal)',
        'description': 'Jadwal servis standar lokal karena koneksi AI sibuk.',
        'interval_mileage': 10000,
        'interval_months': 6,
        'last_service_mileage': mileage,
        'last_service_date': nowDate.toIso8601String(),
        'next_predicted_date': nowDate.add(const Duration(days: 180)).toIso8601String(),
        'next_predicted_mileage': mileage + 10000,
        'is_enabled': 1,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Manajemen Kendaraan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : _vehicles.isEmpty
              ? _buildEmptyState()
              : _buildVehicleList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Tambah Kendaraan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.car, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Belum ada kendaraan terdaftar', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Tambahkan mobil Anda secara manual untuk dianalisis oleh AI',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final v = _vehicles[index];
        final name = v['name'] as String;
        final year = v['year'] as int;
        final engine = v['engine_type'] as String;
        final trans = v['transmission_type'] as String;
        final fuel = v['fuel_type'] as String;
        final mileage = v['current_mileage'] as int;
        final uuid = v['uuid'] as String;

        final isActive = uuid == _activeVehicleUuid;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? AppTheme.neonCyan.withOpacity(0.3) : Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.car, color: AppTheme.neonCyan, size: 18),
                      const SizedBox(width: 12),
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Aktif', style: TextStyle(color: AppTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Spesifikasi: $year • $engine • $trans • $fuel',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text('Odometer: $mileage km', style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isActive)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activeVehicleUuid = uuid;
                        });
                      },
                      child: const Text('Jadikan Aktif', style: TextStyle(color: AppTheme.neonCyan)),
                    ),
                  if (uuid != 'default-honda-jazz-ge8') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.neonOrange),
                      onPressed: () async {
                        await AppDatabase.deleteVehicle(uuid);
                        _loadVehicles();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

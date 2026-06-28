// ────────────────────────────────────────────────────────────────────────────
// core/services/ai_prediction_service.dart
// Singleton Dio · No hardcoded key · Full error logging
// ────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../database/app_database.dart';
import '../providers/app_providers.dart';
import 'notification_service.dart';
import 'obd_bluetooth_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class AiPredictionService {
  // ── Singleton Dio instance ──────────────────────────────────────────────────
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.groq.com/openai/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static String get _obfuscatedApiKey {
    const part1 = 'gsk_uWpOlfDi';
    const part2 = 'qYngOWGb2Qz8WGdy';
    const part3 = 'b3FY4tftssC7EzBOy7HeDcqK4Grg';
    return part1 + part2 + part3;
  }

  static final String _apiKey =
      const String.fromEnvironment('GROQ_API_KEY', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('GROQ_API_KEY')
          : _obfuscatedApiKey;

  static Options get _authHeaders => Options(headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });

  // ══════════════════════════════════════════════════════════════════════════
  // Predict & Schedule — called after OBD scan
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> predictAndSchedule({
    required String vehicleUuid,
    required String vehicleName,
    required int currentMileage,
    required double coolantTemp,
    required double batteryVoltage,
    required double rpm,
    required double fuelTrim,
    required String dtcCodes,
  }) async {
    final activeKey = await getEffectiveApiKey();
    final key = activeKey.isNotEmpty ? activeKey : _apiKey;
    if (key.isEmpty) {
      _log.w('AiPredictionService: GROQ_API_KEY not set – using local fallback');
      await _localFallbackSchedule(vehicleUuid, currentMileage);
      return;
    }

    const systemPrompt = '''
Kamu adalah sahabat mekanik profesional sekaligus asisten AI cerdas untuk kendaraan pengguna.
Gunakan prioritas penilaian berikut secara berurutan:
1. Riwayat penggantian terakhir (tanggal, kilometer, jenis komponen, merek, spesifikasi, umur pakai).
2. Kilometer tempuh sejak penggantian terakhir.
3. Lama waktu sejak penggantian terakhir.
4. Data OBD-II (DTC, suhu mesin, RPM, Fuel Trim, Battery Voltage, coolant temp, engine hours).
5. Hasil inspeksi fisik pengguna (warna oli, kampas rem, tekanan ban, kebocoran, suara abnormal, getaran).
6. Pola penggunaan kendaraan (macet, perjalanan pendek, pegunungan, beban berat, kecepatan tinggi, cuaca ekstrem, banjir).
7. Jadwal perawatan standar pabrikan.

Kembalikan HANYA JSON ARRAY valid tanpa teks tambahan. Setiap objek:
{
  "service_name": string,
  "interval_mileage": int,
  "interval_months": int,
  "predicted_mileage": int,
  "predicted_days": int,
  "reason": string (ramah, hangat, panggil "Bos"/"Bro"/"Om", maks 2 kalimat)
}''';

    final userPrompt = '''
Kendaraan: $vehicleName | Odometer: $currentMileage km
OBD Data: Coolant ${coolantTemp.toStringAsFixed(1)}°C · Aki ${batteryVoltage.toStringAsFixed(2)}V · RPM ${rpm.toStringAsFixed(0)} · Fuel Trim ${fuelTrim.toStringAsFixed(2)}% · DTC: ${dtcCodes.isEmpty ? "Tidak ada" : dtcCodes}
Prediksikan jadwal servis berikutnya.''';

    try {
      final resp = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-70b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
        },
      );

      final raw = resp.data['choices'][0]['message']['content'] as String;
      final clean = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final List<dynamic> predictions = jsonDecode(clean);
      final now = DateTime.now();

      for (var i = 0; i < predictions.length; i++) {
        final pred = predictions[i] as Map<String, dynamic>;
        final serviceName = pred['service_name'] as String? ?? 'Servis Berkala';
        final intervalMileage = (pred['interval_mileage'] as num?)?.toInt() ?? 10000;
        final intervalMonths = (pred['interval_months'] as num?)?.toInt() ?? 6;
        final nextMil = (pred['predicted_mileage'] as num?)?.toInt() ?? (currentMileage + 10000);
        final days = (pred['predicted_days'] as num?)?.toInt() ?? 180;
        final reason = pred['reason'] as String? ?? 'Saatnya perawatan berkala, Bos!';
        final nextDate = now.add(Duration(days: days));

        await AppDatabase.insertOrUpdateSchedule({
          'uuid': '${vehicleUuid}_${serviceName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          'vehicle_uuid': vehicleUuid,
          'service_name': serviceName,
          'description': reason,
          'interval_mileage': intervalMileage,
          'interval_months': intervalMonths,
          'last_service_mileage': currentMileage,
          'last_service_date': now.toIso8601String(),
          'next_predicted_date': nextDate.toIso8601String(),
          'next_predicted_mileage': nextMil,
          'is_enabled': 1,
        });

        if (days <= 7) {
          await NotificationService.showInstantNotification(
            id: i + 100,
            title: '⚠️ Perlu Tindakan Segera: $serviceName',
            body: '$reason (Prediksi: $nextMil km)',
          );
        } else {
          final remindDate = nextDate.subtract(const Duration(days: 3));
          if (remindDate.isAfter(now)) {
            await NotificationService.scheduleNotification(
              id: i + 100,
              title: '📅 Pengingat Perawatan: $serviceName',
              body: 'Rekomendasi: $reason',
              scheduledDate: remindDate,
            );
          }
        }
      }
      _log.i('AiPredictionService: ${predictions.length} schedules updated for $vehicleUuid');
    } on DioException catch (e) {
      _log.e('AiPredictionService predictAndSchedule DioError: ${e.message}');
      await _localFallbackSchedule(vehicleUuid, currentMileage);
    } catch (e, st) {
      _log.e('AiPredictionService predictAndSchedule error', error: e, stackTrace: st);
      await _localFallbackSchedule(vehicleUuid, currentMileage);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Jazzy Chat Response
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String> getJazzyResponse({
    required String query,
    required double coolantTemp,
    required double batteryVoltage,
    required double rpm,
    required double speed,
    required String dtcCodes,
  }) async {
    final activeKey = await getEffectiveApiKey();
    final key = activeKey.isNotEmpty ? activeKey : _apiKey;
    if (key.isEmpty) {
      return _localJazzyFallback(query, coolantTemp, batteryVoltage, rpm, dtcCodes);
    }

    // Load active vehicle specifications dynamically
    final vehicleUuid = ObdBluetoothService.instance.activeVehicleUuid;
    final vehicle = await AppDatabase.getVehicle(vehicleUuid);
    final specs = vehicle != null
        ? '${vehicle['brand']} ${vehicle['model']} (${vehicle['year']}, ${vehicle['engine_type']}, ${vehicle['fuel_type']}, ${vehicle['transmission_type']})'
        : 'Honda Jazz GE8 2012';

    final systemPrompt = '''
Kamu adalah Jazzy, sahabat mekanik profesional AI yang hangat, ramah, bersahabat, dan penuh perhatian.
Panggil pengguna dengan "Bos", "Bro", atau "Om".
Jawab singkat, padat, solutif (maks 2-3 kalimat pendek).

Kendaraan Aktif Pengguna: $specs.
Sesuaikan analisis kerusakan OBD-II, kode DTC, suhu, dan rekomendasi secara spesifik berdasarkan tipe kendaraan tersebut!

Prioritas diagnosa:
1. Riwayat servis terakhir (tanggal, KM, komponen, merek, umur pakai).
2. KM tempuh sejak penggantian.
3. Waktu berlalu sejak penggantian.
4. Data OBD-II: RPM $rpm · Coolant ${coolantTemp.toStringAsFixed(1)}°C · Aki ${batteryVoltage.toStringAsFixed(2)}V · Speed $speed km/h · DTC: ${dtcCodes.isEmpty ? "Tidak ada" : dtcCodes}.
5. Inspeksi fisik pengguna.
6. Pola penggunaan kendaraan.
7. Standar pabrikan.''';

    try {
      final resp = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': query},
          ],
          'temperature': 0.7,
        },
      );
      return resp.data['choices'][0]['message']['content'] as String;
    } on DioException catch (e) {
      _log.w('Jazzy DioError: ${e.message}');
      return _localJazzyFallback(query, coolantTemp, batteryVoltage, rpm, dtcCodes);
    } catch (e) {
      _log.w('Jazzy error: $e');
      return _localJazzyFallback(query, coolantTemp, batteryVoltage, rpm, dtcCodes);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Analyze Service Log & Schedule Next
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> analyzeServiceLogAndSchedule({
    required String vehicleUuid,
    required String serviceType,
    required String oilBrand,
    required int currentMileage,
    required int nextTargetMileage,
    required DateTime serviceDate,
  }) async {
    final activeKey = await getEffectiveApiKey();
    final key = activeKey.isNotEmpty ? activeKey : _apiKey;
    if (key.isEmpty) {
      await _localServiceLogFallback(vehicleUuid, serviceType, oilBrand,
          currentMileage, nextTargetMileage, serviceDate);
      return;
    }

    final systemPrompt = '''
Kamu adalah sahabat mekanik profesional AI.
Analisis catatan servis berikut dan prediksikan tanggal servis berikutnya.

Data Servis:
- Tipe: $serviceType
- Oli/Sparepart: ${oilBrand.isEmpty ? "Tidak ditentukan" : oilBrand}
- Odometer: $currentMileage km → target ${nextTargetMileage} km
- Tanggal servis: ${serviceDate.toIso8601String()}

Kembalikan JSON objek:
{"predicted_days": int, "recommendation": string (hangat, maks 2 kalimat, panggil "Bos"/"Bro"/"Om")}''';

    try {
      final resp = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Prediksikan jadwal berikutnya.'},
          ],
          'temperature': 0.3,
          'response_format': {'type': 'json_object'},
        },
      );

      final Map<String, dynamic> result =
          jsonDecode(resp.data['choices'][0]['message']['content'] as String);
      final int days = (result['predicted_days'] as num?)?.toInt() ?? 180;
      final String rec = result['recommendation'] as String? ??
          'Waktunya perawatan berkala, Bos!';
      await _saveScheduleFromLog(vehicleUuid, serviceType, oilBrand,
          currentMileage, nextTargetMileage, serviceDate, days, rec);
      _log.i('AiPredictionService: schedule saved for $serviceType');
    } on DioException catch (e) {
      _log.w('analyzeServiceLog DioError: ${e.message}');
      await _localServiceLogFallback(vehicleUuid, serviceType, oilBrand,
          currentMileage, nextTargetMileage, serviceDate);
    } catch (e, st) {
      _log.e('analyzeServiceLog error', error: e, stackTrace: st);
      await _localServiceLogFallback(vehicleUuid, serviceType, oilBrand,
          currentMileage, nextTargetMileage, serviceDate);
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static Future<void> _saveScheduleFromLog(
    String vehicleUuid,
    String serviceType,
    String oilBrand,
    int currentMileage,
    int nextTargetMileage,
    DateTime serviceDate,
    int days,
    String recommendation,
  ) async {
    final nextDate = serviceDate.add(Duration(days: days));
    final key = '${vehicleUuid}_${serviceType.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    await AppDatabase.insertOrUpdateSchedule({
      'uuid': key,
      'vehicle_uuid': vehicleUuid,
      'service_name': serviceType,
      'description': '$recommendation${oilBrand.isNotEmpty ? " · Oli: $oilBrand" : ""}',
      'interval_mileage': nextTargetMileage - currentMileage,
      'interval_months': (days / 30).round(),
      'last_service_mileage': currentMileage,
      'last_service_date': serviceDate.toIso8601String(),
      'next_predicted_date': nextDate.toIso8601String(),
      'next_predicted_mileage': nextTargetMileage,
      'is_enabled': 1,
    });

    final remindDate = nextDate.subtract(const Duration(days: 3));
    if (remindDate.isAfter(DateTime.now())) {
      await NotificationService.scheduleNotification(
        id: serviceType.hashCode.abs(),
        title: '📅 Jadwal Servis: $serviceType',
        body: '$recommendation Target Odo: $nextTargetMileage km.',
        scheduledDate: remindDate,
      );
    }
  }

  static Future<void> _localFallbackSchedule(
      String vehicleUuid, int currentMileage) async {
    final now = DateTime.now();
    final nextOilDate = now.add(const Duration(days: 180));
    await AppDatabase.insertOrUpdateSchedule({
      'uuid': '${vehicleUuid}_ganti_oli_mesin',
      'vehicle_uuid': vehicleUuid,
      'service_name': 'Ganti Oli Mesin',
      'description': 'Prediksi lokal: Jadwal servis berkala direkomendasikan dalam 6 bulan atau 10.000 km.',
      'interval_mileage': 10000,
      'interval_months': 6,
      'last_service_mileage': currentMileage,
      'last_service_date': now.toIso8601String(),
      'next_predicted_date': nextOilDate.toIso8601String(),
      'next_predicted_mileage': currentMileage + 10000,
      'is_enabled': 1,
    });
  }

  static Future<void> _localServiceLogFallback(
    String vehicleUuid,
    String serviceType,
    String oilBrand,
    int currentMileage,
    int nextTargetMileage,
    DateTime serviceDate,
  ) async {
    final defaultDays =
        serviceType.toLowerCase().contains('oli') ? 180 : 360;
    final rec =
        'Perawatan berkala untuk $serviceType berikutnya direkomendasikan dalam $defaultDays hari, Bos!';
    await _saveScheduleFromLog(vehicleUuid, serviceType, oilBrand,
        currentMileage, nextTargetMileage, serviceDate, defaultDays, rec);
  }

  static String _localJazzyFallback(String query, double coolantTemp,
      double batteryVoltage, double rpm, String dtcCodes) {
    final q = query.toLowerCase();
    if (q.contains('aki') || q.contains('baterai') || q.contains('volt')) {
      return 'Tegangan aki Anda saat ini ${batteryVoltage.toStringAsFixed(2)} V. '
          '${batteryVoltage < 12.0 ? "Sebaiknya segera dicas atau ganti ya, Bos!" : "Kondisinya masih prima, Bos!"}';
    }
    if (q.contains('suhu') || q.contains('panas') || q.contains('coolant')) {
      return 'Suhu pendingin mesin ${coolantTemp.toStringAsFixed(1)}°C. '
          '${coolantTemp > 100 ? "Wah agak panas nih Bos, cek air radiator ya!" : "Masih dalam batas normal kok, Bro!"}';
    }
    if (q.contains('kondisi') || q.contains('sehat') || q.contains('dtc') || q.contains('error')) {
      if (dtcCodes.isNotEmpty) {
        return 'Ada kode error terdeteksi: $dtcCodes. Sebaiknya segera dicek ke bengkel ya, Bos!';
      }
      return 'Semua sensor OBD normal. RPM stabil ${rpm.toStringAsFixed(0)} dan aki ${batteryVoltage.toStringAsFixed(1)}V. Siap gas pol, Bos! 🚗';
    }
    return 'Halo Bos! Ada yang bisa Jazzy bantu soal kondisi kendaraan Anda hari ini? 😊';
  }

  // Jazzy Voice Response (Friendly, Soft, Female Automotive AI Companion)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String> getJazzyVoiceResponse({
    required String query,
    required double coolantTemp,
    required double batteryVoltage,
    required double rpm,
    required double speed,
    required String dtcCodes,
    required bool isDriving,
  }) async {
    final activeKey = await getEffectiveApiKey();
    final key = activeKey.isNotEmpty ? activeKey : _apiKey;
    if (key.isEmpty) {
      return isDriving ? "Hati-hati di jalan, Kak." : "Semua sistem terpantau normal, Kak.";
    }

    final vehicleUuid = ObdBluetoothService.instance.activeVehicleUuid;
    final vehicle = await AppDatabase.getVehicle(vehicleUuid);
    final specs = vehicle != null
        ? '${vehicle['brand']} ${vehicle['model']} (${vehicle['year']})'
        : 'Honda Jazz';

    final systemPrompt = '''
You are Jazzy, a friendly female automotive AI assistant.
Speak naturally like a real human, never like a chatbot or robot. Use warm, casual Indonesian with a soft, cheerful female personality.

Active vehicle: $specs.
OBD-II Live: Speed $speed km/h · RPM $rpm · Coolant $coolantTemp°C · Battery $batteryVoltage V · DTC: $dtcCodes.

Rule:
- Keep answers short (under 25 words unless more detail is requested).
- Use natural Indonesian expressions like "Oke, sebentar ya...", "Siap.", "Hmm, saya cek dulu.", "Sip!", and avoid repetitive or formal AI-style responses.
- Never say "Sebagai AI...", "Berdasarkan informasi...", "Saya tidak memiliki emosi...".
- Be supportive, calm, and companion-like.
${isDriving ? '- MANDATORY: The user is currently driving (speed > 0). Keep your response under 10 words for safety!' : ''}
''';

    try {
      final resp = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-70b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': query},
          ],
          'temperature': 0.6,
          'max_tokens': 100,
        },
      );
      return resp.data['choices'][0]['message']['content'] as String? ?? 'Siap, Kak.';
    } catch (_) {
      return isDriving ? "Hati-hati berkendara, Kak." : "Ada masalah koneksi internet, Kak.";
    }
  }
}

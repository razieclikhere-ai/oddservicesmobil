import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/app_database.dart';
import 'notification_service.dart';

class AiPredictionService {
  static final String _apiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  
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
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final systemPrompt = '''
Kamu adalah asisten mekanik AI profesional yang bertugas menganalisis parameter OBD-II kendaraan dan memprediksi jadwal perawatan/servis berikutnya.
Kembalikan respon HANYA dalam format JSON ARRAY yang valid, tanpa teks penjelasan tambahan, pembuka, penutup, atau tanda markdown.

Setiap objek di dalam array harus memiliki properti berikut:
1. "service_name": Nama komponen/servis (contoh: "Ganti Oli Mesin", "Cek Baterai/Aki", "Pembersihan Filter Udara", "Inspeksi Sistem Rem")
2. "interval_mileage": Interval kilometer standar untuk servis ini (dalam angka saja)
3. "interval_months": Interval bulan standar untuk servis ini (dalam angka saja)
4. "predicted_mileage": Odometer prediksi saat servis ini harus dilakukan (angka saja)
5. "predicted_days": Estimasi berapa hari dari sekarang servis ini harus dilakukan berdasarkan kondisi sensor saat ini (angka saja)
6. "reason": Alasan mengapa jadwal ini direkomendasikan berdasarkan data OBD (contoh: "Aki terdeteksi 11.8V, butuh pengisian/penggantian segera")
''';

    final userPrompt = '''
Menganalisis kendaraan: $vehicleName
Odometer Saat Ini: $currentMileage km
Data OBD Sensor Terbaru:
- Suhu Pendingin (Coolant): $coolantTemp °C
- Tegangan Aki (Voltage): $batteryVoltage V
- Putaran Mesin (RPM): $rpm RPM
- Fuel Trim: $fuelTrim %
- Kode Error (DTC): ${dtcCodes.isEmpty ? "Tidak ada" : dtcCodes}

Berdasarkan parameter di atas, tentukan/prediksikan jadwal servis/perawatan berkala berikutnya yang perlu diperhatikan pengguna.
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
      // Parse the JSON array
      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> predictions = jsonDecode(cleanJson);

      final now = DateTime.now();

      for (var i = 0; i < predictions.length; i++) {
        final pred = predictions[i];
        final serviceName = pred['service_name'] as String;
        final intervalMileage = pred['interval_mileage'] as int;
        final intervalMonths = pred['interval_months'] as int;
        final nextMil = pred['predicted_mileage'] as int;
        final days = pred['predicted_days'] as int;
        final reason = pred['reason'] as String;

        final nextDate = now.add(Duration(days: days));

        // Save schedule to database
        await AppDatabase.insertOrUpdateSchedule({
          'uuid': '${vehicleUuid}_${serviceName.toLowerCase().replaceAll(' ', '_')}',
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

        // Trigger or schedule notifications
        if (days <= 7) {
          // Urgent notification
          await NotificationService.showInstantNotification(
            id: i + 100,
            title: '⚠️ Perlu Tindakan Segera: $serviceName',
            body: '$reason (Prediksi: $nextMil km)',
          );
        } else {
          // Scheduled reminder
          await NotificationService.scheduleNotification(
            id: i + 100,
            title: '📅 Pengingat Perawatan: $serviceName',
            body: 'Jadwal servis berkala Anda berikutnya untuk $serviceName. Rekomendasi: $reason',
            scheduledDate: nextDate.subtract(const Duration(days: 3)), // Remind 3 days before
          );
        }
      }
    } catch (e) {
      // Fallback local rules prediction if Groq fails or no API Key
      final now = DateTime.now();
      
      // Simple local logic for Oil Change
      final nextOilDate = now.add(const Duration(days: 180));
      await AppDatabase.insertOrUpdateSchedule({
        'uuid': '${vehicleUuid}_oil_change',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Ganti Oli Mesin (Lokal)',
        'description': 'Prediksi cadangan karena koneksi AI sibuk. Silakan lakukan pemeriksaan berkala rutin.',
        'interval_mileage': 10000,
        'interval_months': 6,
        'last_service_mileage': currentMileage,
        'last_service_date': now.toIso8601String(),
        'next_predicted_date': nextOilDate.toIso8601String(),
        'next_predicted_mileage': currentMileage + 10000,
        'is_enabled': 1,
      });

      await NotificationService.scheduleNotification(
        id: 999,
        title: '📅 Pengingat Perawatan: Ganti Oli Mesin',
        body: 'Jadwal servis berkala oli mesin Anda berikutnya.',
        scheduledDate: nextOilDate.subtract(const Duration(days: 3)),
      );
    }
  }
}

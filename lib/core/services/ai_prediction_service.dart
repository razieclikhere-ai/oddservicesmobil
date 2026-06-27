import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/app_database.dart';
import 'notification_service.dart';

class AiPredictionService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  
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
Kamu adalah sahabat mekanik profesional sekaligus asisten AI cerdas untuk kendaraan pengguna. Tugasmu menganalisis parameter OBD-II kendaraan dan memprediksi jadwal perawatan/servis berikutnya.
Kembalikan respon HANYA dalam format JSON ARRAY yang valid, tanpa teks penjelasan tambahan, pembuka, penutup, atau tanda markdown.

Setiap objek di dalam array harus memiliki properti berikut:
1. "service_name": Nama komponen/servis (contoh: "Ganti Oli Mesin", "Cek Baterai/Aki", "Pembersihan Filter Udara", "Inspeksi Sistem Rem")
2. "interval_mileage": Interval kilometer standar untuk servis ini (dalam angka saja)
3. "interval_months": Interval bulan standar untuk servis ini (dalam angka saja)
4. "predicted_mileage": Odometer prediksi saat servis ini harus dilakukan (angka saja)
5. "predicted_days": Estimasi berapa hari dari sekarang servis ini harus dilakukan berdasarkan kondisi sensor saat ini (angka saja)
6. "reason": Alasan mengapa jadwal ini direkomendasikan dengan gaya bicara yang sangat ramah, hangat, personal, dan penuh perhatian layaknya seorang sahabat dekat yang mengerti kebutuhan mobil mereka (panggil dengan "Bos", "Bro", atau "Om"). Contoh: "Aki mobilmu terdeteksi 11.8V nih Bos, agak lemah. Sebaiknya dicharge atau diganti biar tidak mogok di jalan ya."
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

  static Future<String> getJazzyResponse({
    required String query,
    required double coolantTemp,
    required double batteryVoltage,
    required double rpm,
    required double speed,
    required String dtcCodes,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    final systemPrompt = '''
Kamu adalah Jazzy, sahabat mekanik profesional sekaligus asisten AI cerdas untuk mobil Honda Jazz GE8 milik pengguna.
Gaya bicaramu sangat hangat, ramah, bersahabat, penuh perhatian, dan empati layaknya sahabat dekat yang sangat mengerti kebutuhan mobil mereka.
Panggil pengguna dengan sebutan akrab seperti "Bos", "Bro", atau "Om".
Jawab pertanyaan mereka seolah-olah kamu sedang berbicara langsung secara alami, singkat, padat, dan solutif (maksimal 2 kalimat pendek).
Berikut adalah data sensor OBD-II mobil saat ini:
- RPM: $rpm RPM
- Suhu Pendingin (Coolant): $coolantTemp °C
- Tegangan Aki (Voltage): $batteryVoltage V
- Kecepatan: $speed km/h
- Kode Error (DTC): ${dtcCodes.isEmpty ? "Tidak ada" : dtcCodes}
''';

    try {
      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': query},
          ],
          'temperature': 0.7,
        },
      );

      return response.data['choices'][0]['message']['content'] as String;
    } catch (_) {
      final q = query.toLowerCase();
      if (q.contains('aki') || q.contains('baterai') || q.contains('volt')) {
        return 'Tegangan aki Anda saat ini ${batteryVoltage.toStringAsFixed(2)} Volt. Kondisinya ${batteryVoltage < 12.0 ? "lemah, sebaiknya segera dicas atau ganti" : "sangat prima, Bos!"}';
      }
      if (q.contains('suhu') || q.contains('panas') || q.contains('coolant') || q.contains('temperatur')) {
        return 'Suhu pendingin mesin saat ini ${coolantTemp.toStringAsFixed(1)} derajat Celsius. ${coolantTemp > 100 ? "Wah, agak panas nih Bos. Cek air radiator ya!" : "Mesin masih dalam suhu kerja normal."}';
      }
      if (q.contains('kondisi') || q.contains('sehat') || q.contains('kerusakan') || q.contains('error') || q.contains('dtc')) {
        if (dtcCodes.isNotEmpty) {
          return 'Ada kode error terdeteksi yaitu $dtcCodes. Sebaiknya Anda menanyakan masalah ini ke asisten AI di tab tanya mekanik.';
        }
        return 'Semua sensor OBD termonitor normal. RPM stabil di ${rpm.toStringAsFixed(0)} dan tegangan baterai ${batteryVoltage.toStringAsFixed(1)} Volt. Siap gas pol, Bos!';
      }
      return 'Halo Bos! Ada yang bisa Jazzy bantu soal kondisi mesin Honda Jazz GE8 Anda hari ini?';
    }
  }

  static Future<void> analyzeServiceLogAndSchedule({
    required String vehicleUuid,
    required String serviceType,
    required String oilBrand,
    required int currentMileage,
    required int nextTargetMileage,
    required DateTime serviceDate,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    final systemPrompt = '''
Kamu adalah sahabat mekanik profesional AI. Tugasmu menganalisis catatan servis yang baru dilakukan dan memperkirakan tanggal rekomendasi servis berikutnya.
Analisis data berikut:
- Tipe Servis: $serviceType
- Merek Oli/Sparepart: ${oilBrand.isEmpty ? "Tidak ditentukan" : oilBrand}
- Odometer saat Servis: $currentMileage km
- Target Odometer Servis Berikutnya: $nextTargetMileage km
- Tanggal Servis: ${serviceDate.toIso8601String()}

Kembalikan hasil dalam format JSON objek dengan properti berikut:
1. "predicted_days": jumlah hari dari tanggal servis saat ini untuk melakukan servis berikutnya (angka saja, misalnya 180).
2. "recommendation": rekomendasi hangat dan ramah layaknya sahabat (maksimal 2 kalimat, panggil pengguna dengan "Bos", "Bro", atau "Om").
''';

    try {
      final response = await dio.post(
        '/chat/completions',
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

      final cleanJson = response.data['choices'][0]['message']['content'] as String;
      final Map<String, dynamic> result = jsonDecode(cleanJson);
      final int days = result['predicted_days'] as int? ?? 180;
      final String recommendation = result['recommendation'] as String? ?? 'Waktunya melakukan perawatan berkala, Bos!';

      final nextDate = serviceDate.add(Duration(days: days));

      // Update service schedule in database
      await AppDatabase.insertOrUpdateSchedule({
        'uuid': '${vehicleUuid}_${serviceType.toLowerCase().replaceAll(' ', '_')}',
        'vehicle_uuid': vehicleUuid,
        'service_name': serviceType,
        'description': '$recommendation (Oli: $oilBrand)',
        'interval_mileage': nextTargetMileage - currentMileage,
        'interval_months': (days / 30).round(),
        'last_service_mileage': currentMileage,
        'last_service_date': serviceDate.toIso8601String(),
        'next_predicted_date': nextDate.toIso8601String(),
        'next_predicted_mileage': nextTargetMileage,
        'is_enabled': 1,
      });

      // Schedule notification
      await NotificationService.scheduleNotification(
        id: serviceType.hashCode,
        title: '📅 Jadwal Servis: $serviceType',
        body: '$recommendation Target Odo: $nextTargetMileage km.',
        scheduledDate: nextDate.subtract(const Duration(days: 3)),
      );
    } catch (_) {
      // Local fallback prediction if Groq fails
      final int defaultDays = serviceType.toLowerCase().contains('oli') ? 180 : 360;
      final nextDate = serviceDate.add(Duration(days: defaultDays));
      final rec = 'Prediksi lokal: Perawatan berkala untuk $serviceType berikutnya direkomendasikan dalam $defaultDays hari.';

      await AppDatabase.insertOrUpdateSchedule({
        'uuid': '${vehicleUuid}_${serviceType.toLowerCase().replaceAll(' ', '_')}',
        'vehicle_uuid': vehicleUuid,
        'service_name': serviceType,
        'description': '$rec (Oli: $oilBrand)',
        'interval_mileage': nextTargetMileage - currentMileage,
        'interval_months': (defaultDays / 30).round(),
        'last_service_mileage': currentMileage,
        'last_service_date': serviceDate.toIso8601String(),
        'next_predicted_date': nextDate.toIso8601String(),
        'next_predicted_mileage': nextTargetMileage,
        'is_enabled': 1,
      });

      await NotificationService.scheduleNotification(
        id: serviceType.hashCode,
        title: '📅 Pengingat Servis: $serviceType',
        body: 'Jangan lupa untuk melakukan servis $serviceType di $nextTargetMileage km.',
        scheduledDate: nextDate.subtract(const Duration(days: 3)),
      );
    }
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';

class OBDData {
  final double coolantTemp; // in Celsius
  final double batteryVoltage; // in Volts
  final double fuelTrim; // in percentage
  final bool misfireDetected;
  final List<String> dtcs;
  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;

  OBDData({
    required this.coolantTemp,
    required this.batteryVoltage,
    required this.fuelTrim,
    required this.misfireDetected,
    required this.dtcs,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleYear,
  });
}

class AnalysisResult {
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final String? estimateCost;

  AnalysisResult({
    required this.title,
    required this.message,
    required this.severity,
    this.estimateCost,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      title: json['title'] ?? 'Info',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'info',
      estimateCost: json['estimateCost'],
    );
  }
}

class AIAnalyzer {
  final String? _apiKey;
  final Dio _dio;

  AIAnalyzer({String? apiKey}) 
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: 'https://api.groq.com/openai/v1',
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ));

  Future<List<AnalysisResult>> evaluate(OBDData data) async {
    List<AnalysisResult> results = [];

    // Fallback/Safety Logic (Offline)
    if (data.coolantTemp > 105.0) {
      results.add(AnalysisResult(
        title: 'Peringatan Overheating',
        message: 'Suhu pendingin mesin melebihi batas aman (>105°C). Segera matikan mesin untuk mencegah kerusakan.',
        severity: 'critical',
      ));
    }

    if (data.batteryVoltage < 12.2) {
      results.add(AnalysisResult(
        title: 'Aki Melemah',
        message: 'Tegangan aki berada di bawah 12.2V. Pertimbangkan untuk mengecas atau mengganti aki.',
        severity: 'warning',
        estimateCost: 'Cek ke bengkel',
      ));
    }

    // Dynamic AI Evaluation for DTCs via Groq API
    if (_apiKey != null && _apiKey!.isNotEmpty && data.dtcs.isNotEmpty) {
      try {
        final prompt = '''
Sebagai mekanik ahli mobil, analisis kode DTC berikut untuk mobil ${data.vehicleYear} ${data.vehicleMake} ${data.vehicleModel}:
DTCs: ${data.dtcs.join(', ')}

Berikan analisis dalam format JSON array yang berisi objek dengan keys:
- "title": Judul masalah
- "message": Penjelasan detail penyebab dan tindakan yang harus dilakukan
- "severity": "info", "warning", atau "critical"
- "estimateCost": Estimasi biaya perbaikan di Indonesia (dalam Rupiah, contoh "Rp 1.500.000")

Hanya kembalikan valid JSON array tanpa format markdown, tanpa tag \`\`\`json, dan tanpa penjelasan lain.
''';

        final response = await _dio.post(
          '/chat/completions',
          data: {
            'model': 'llama3-70b-8192',
            'messages': [
              {'role': 'system', 'content': 'You are a helpful assistant that strictly outputs JSON arrays.'},
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.2,
          },
        );

        if (response.statusCode == 200) {
          final String contentText = response.data['choices'][0]['message']['content'] ?? '[]';
          final text = contentText.replaceAll('```json', '').replaceAll('```', '').trim();
          final List<dynamic> jsonList = jsonDecode(text);
          for (var item in jsonList) {
            results.add(AnalysisResult.fromJson(item));
          }
        }
      } catch (e) {
        // Fallback if AI fails
        for (var code in data.dtcs) {
          results.add(AnalysisResult(
            title: 'DTC Terdeteksi: $code',
            message: 'Terdapat masalah yang direkam oleh sistem (AI Gagal merespons).',
            severity: 'info',
          ));
        }
      }
    } else {
      // Offline fallback for DTCs
      for (var code in data.dtcs) {
        results.add(AnalysisResult(
          title: 'DTC Terdeteksi: $code',
          message: 'Terdapat masalah yang direkam oleh sistem kendaraan dengan kode $code.',
          severity: 'info',
        ));
      }
    }

    return results;
  }
}

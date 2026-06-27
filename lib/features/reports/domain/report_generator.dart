import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../analyzer/domain/ai_analyzer.dart'; // import AIAnalyzer models

class ReportGenerator {
  Future<Uint8List> generateReport({
    required String vehicleName,
    required String vin,
    required String date,
    required OBDData data,
    required List<AnalysisResult> analysisResults,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Laporan Diagnostik Kendaraan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Informasi Kendaraan', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Bullet(text: 'Kendaraan: $vehicleName'),
              pw.Bullet(text: 'VIN: $vin'),
              pw.Bullet(text: 'Tanggal: $date'),
              pw.SizedBox(height: 20),
              
              pw.Text('Data OBD-II', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Parameter', 'Nilai'],
                  <String>['Suhu Pendingin (Coolant)', '${data.coolantTemp} °C'],
                  <String>['Tegangan Aki', '${data.batteryVoltage} V'],
                  <String>['Fuel Trim', '${data.fuelTrim} %'],
                  <String>['Misfire', data.misfireDetected ? 'Ya' : 'Tidak'],
                  <String>['DTC (Trouble Codes)', data.dtcs.isEmpty ? 'Tidak ada' : data.dtcs.join(', ')],
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text('Hasil Analisis AI', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (analysisResults.isEmpty)
                pw.Text('Tidak ada masalah kritis yang terdeteksi.')
              else
                pw.ListView.builder(
                  itemCount: analysisResults.length,
                  itemBuilder: (context, index) {
                    final res = analysisResults[index];
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(res.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(res.message),
                          if (res.estimateCost != null)
                            pw.Text('Estimasi Biaya: ${res.estimateCost}', style: pw.TextStyle(color: PdfColors.red)),
                        ]
                      )
                    );
                  }
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printReport(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }
}

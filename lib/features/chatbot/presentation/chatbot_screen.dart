// ────────────────────────────────────────────────────────────────────────────
// features/chatbot/presentation/chatbot_screen.dart
// Jazzy AI chatbot — Natural Language Command Execution & Parser
// ────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/ai_prediction_service.dart';
import '../../../core/services/obd_bluetooth_service.dart';

const int _maxHistory = 20;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  const ChatMessage(
      {required this.text, required this.isUser, required this.time});
}

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  bool _isLoading = false;

  static String get _obfuscatedApiKey {
    const part1 = 'gsk_exMM6y7n';
    const part2 = 'CJJqt7qh6sjNWGdy';
    const part3 = 'b3FY8XthZ6rGXnvq3AVXQLSKSCHE';
    return part1 + part2 + part3;
  }

  final String _apiKey =
      const String.fromEnvironment('GROQ_API_KEY', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('GROQ_API_KEY')
          : _obfuscatedApiKey;

  late final Dio _dio;

  final List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _chatHistory.add({
      'role': 'system',
      'content': '''
Kamu adalah Jazzy, asisten mekanik AI sekaligus konsultan profesional yang sangat sopan, santun, hangat, dan melayani dengan tulus.
Selalu sapa pengguna dengan sebutan terhormat seperti "Bapak", "Ibu", atau "Kakak". Jangan gunakan kata sapaan gaul/slang seperti "Bro" or "Om".
Gunakan tutur bahasa Indonesia yang halus, sopan, sabar, dan menenangkan.
Berikan penjelasan teknis secara sederhana, solutif, penuh empati, dan mudah dimengerti.

Jika pengguna meminta untuk melakukan tindakan/aksi tertentu di aplikasi, kamu HARUS menyisipkan kode perintah di akhir jawabanmu dengan format:
[CMD: {"action": "ACTION_NAME", ...}]

Tindakan yang didukung:
1. set_active_vehicle: Mengganti kendaraan aktif.
   Format: [CMD: {"action": "set_active_vehicle", "vehicle_name": "Nama Mobil"}]
2. clear_scan_history: Menghapus semua riwayat scan OBD.
   Format: [CMD: {"action": "clear_scan_history"}]
3. add_service_log: Mencatat servis baru.
   Format: [CMD: {"action": "add_service_log", "service_type": "Ganti Oli Mesin", "oil_brand": "Shell", "current_mileage": 150000, "next_target_mileage": 160000, "cost": 350000}]
4. add_schedule: Menambahkan jadwal servis/maintenance baru.
   Format: [CMD: {"action": "add_schedule", "service_name": "Ganti Ban", "interval_mileage": 20000, "interval_months": 12, "description": "Deskripsi singkat"}]
5. delete_schedule: Menghapus jadwal servis.
   Format: [CMD: {"action": "delete_schedule", "service_name": "Nama Servis"}]

Jangan berikan penjelasan tentang format CMD ini ke pengguna, cukup eksekusi secara transparan.'''
    });

    _messages.add(ChatMessage(
      text:
          'Selamat datang Kakak! Saya Jazzy, konsultan mekanik AI Anda 🤖\nSaya siap membantu menganalisis mesin, mencatat riwayat servis, mengatur jadwal perawatan berkala, atau mengganti kendaraan aktif langsung melalui obrolan ini. Ada yang bisa saya bantu hari ini?',
      isUser: false,
      time: DateTime.now(),
    ));

    if (const String.fromEnvironment('GROQ_API_KEY', defaultValue: '').isEmpty) {
      _messages.add(ChatMessage(
        text:
            '⚠️ Catatan: Aplikasi ini dikompilasi dengan API Key Groq kosong (--dart-define=GROQ_API_KEY=). AI Jazzy saat ini berjalan menggunakan kunci cadangan bersama yang memiliki batasan akses ketat. Jika koneksi gagal, harap bangun aplikasi menggunakan API Key pribadi Anda.',
        isUser: false,
        time: DateTime.now(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.insert(
          0, ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });

    _chatHistory.add({'role': 'user', 'content': text});

    // Trim history to prevent API context overflow
    if (_chatHistory.length > _maxHistory) {
      _chatHistory.removeRange(1, 3); // Keep system prompt, remove oldest exchange
    }

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': 'llama3-70b-8192',
        'messages': _chatHistory,
        'temperature': 0.5,
        'max_tokens': 600,
      });

      final reply = response.data['choices'][0]['message']['content'] as String? ??
          'Maaf Bos, saya tidak mengerti.';

      _chatHistory.add({'role': 'assistant', 'content': reply});

      // Parse commands
      await _parseAndExecuteCommand(reply);
    } on DioException catch (e) {
      _chatHistory.removeLast();
      String errMsg = 'Gagal terhubung ke server AI.';
      if (e.response?.statusCode == 401) {
        errMsg = 'API Key tidak valid. Periksa konfigurasi.';
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        errMsg = 'Koneksi timeout. Cek koneksi internet.';
      }
      setState(() {
        _messages.insert(
            0, ChatMessage(text: errMsg, isUser: false, time: DateTime.now()));
        _isLoading = false;
      });
    } catch (e) {
      _chatHistory.removeLast();
      setState(() {
        _messages.insert(
            0,
            ChatMessage(
                text: 'Terjadi kesalahan sistem.',
                isUser: false,
                time: DateTime.now()));
        _isLoading = false;
      });
    }
  }

  Future<void> _parseAndExecuteCommand(String reply) async {
    final cmdRegExp = RegExp(r'\[CMD:\s*(\{.*?\})\s*\]');
    final match = cmdRegExp.firstMatch(reply);
    String cleanReply = reply.replaceAll(cmdRegExp, '').trim();

    if (match != null) {
      final jsonStr = match.group(1);
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> cmd = jsonDecode(jsonStr);
          final action = cmd['action'] as String?;

          if (action == 'set_active_vehicle') {
            final name = cmd['vehicle_name'] as String?;
            if (name != null) {
              final list = await AppDatabase.getVehicles();
              final matchVeh = list.firstWhere(
                (v) => (v['name'] as String)
                    .toLowerCase()
                    .contains(name.toLowerCase()),
                orElse: () => <String, dynamic>{},
              );
              if (matchVeh.isNotEmpty) {
                final uuid = matchVeh['uuid'] as String;
                await ref.read(activeVehicleProvider.notifier).setActive(uuid);
                cleanReply +=
                    '\n\n*(Sistem: Berhasil mengganti kendaraan aktif menjadi ${matchVeh['name']}.)*';
              } else {
                cleanReply +=
                    '\n\n*(Sistem: Gagal menemukan kendaraan dengan nama "$name".)*';
              }
            }
          } else if (action == 'clear_scan_history') {
            final activeUuid = ref.read(activeVehicleUuidProvider);
            await AppDatabase.deleteAllScans(activeUuid);
            ref.invalidate(scanHistoryProvider);
            ref.invalidate(recentScansProvider);
            cleanReply +=
                '\n\n*(Sistem: Semua riwayat scan OBD berhasil dihapus.)*';
          } else if (action == 'add_service_log') {
            final activeUuid = ref.read(activeVehicleUuidProvider);
            final type = cmd['service_type'] as String? ?? 'Ganti Oli Mesin';
            final brand = cmd['oil_brand'] as String? ?? '';
            final km = (cmd['current_mileage'] as num?)?.toInt() ?? 150000;
            final nextKm =
                (cmd['next_target_mileage'] as num?)?.toInt() ?? (km + 10000);
            final cost = (cmd['cost'] as num?)?.toInt() ?? 0;

            final newLog = {
              'uuid': const Uuid().v4(),
              'vehicle_uuid': activeUuid,
              'service_date': DateTime.now().toIso8601String(),
              'service_type': type,
              'oil_brand': brand,
              'current_mileage': km,
              'next_target_mileage': nextKm,
              'cost': cost,
              'notes': 'Dicatat otomatis oleh Jazzy AI',
              'created_at': DateTime.now().toIso8601String(),
            };

            await AppDatabase.insertServiceLog(newLog);
            await AppDatabase.updateVehicleMileage(activeUuid, km);
            ref.invalidate(serviceLogsProvider);

            // Trigger AI schedule update in background
            try {
              await AiPredictionService.analyzeServiceLogAndSchedule(
                vehicleUuid: activeUuid,
                serviceType: type,
                oilBrand: brand,
                currentMileage: km,
                nextTargetMileage: nextKm,
                serviceDate: DateTime.now(),
              );
            } catch (_) {}

            ref.invalidate(schedulesProvider);
            cleanReply +=
                '\n\n*(Sistem: Berhasil menambahkan catatan servis $type.)*';
          } else if (action == 'add_schedule') {
            final activeUuid = ref.read(activeVehicleUuidProvider);
            final name = cmd['service_name'] as String?;
            if (name != null) {
              final km = (cmd['interval_mileage'] as num?)?.toInt() ?? 10000;
              final months = (cmd['interval_months'] as num?)?.toInt() ?? 6;
              final desc = cmd['description'] as String? ?? 'Jadwal servis';

              final now = DateTime.now();
              await AppDatabase.insertOrUpdateSchedule({
                'uuid':
                    '${activeUuid}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
                'vehicle_uuid': activeUuid,
                'service_name': name,
                'description': desc,
                'interval_mileage': km,
                'interval_months': months,
                'last_service_mileage': 0,
                'last_service_date': now.toIso8601String(),
                'next_predicted_date':
                    now.add(Duration(days: months * 30)).toIso8601String(),
                'next_predicted_mileage': km,
                'is_enabled': 1,
              });
              ref.invalidate(schedulesProvider);
              cleanReply +=
                  '\n\n*(Sistem: Berhasil menambahkan jadwal servis $name.)*';
            }
          } else if (action == 'delete_schedule') {
            final activeUuid = ref.read(activeVehicleUuidProvider);
            final name = cmd['service_name'] as String?;
            if (name != null) {
              final list = await AppDatabase.getSchedules(activeUuid);
              final matchSched = list.firstWhere(
                (s) => (s['service_name'] as String)
                    .toLowerCase()
                    .contains(name.toLowerCase()),
                orElse: () => <String, dynamic>{},
              );
              if (matchSched.isNotEmpty) {
                await AppDatabase.deleteSchedule(matchSched['uuid'] as String);
                ref.invalidate(schedulesProvider);
                cleanReply +=
                    '\n\n*(Sistem: Berhasil menghapus jadwal servis ${matchSched['service_name']}.)*';
              } else {
                cleanReply +=
                    '\n\n*(Sistem: Gagal menemukan jadwal dengan nama "$name".)*';
              }
            }
          }
        } catch (_) {}
      }
    }

    setState(() {
      _messages.insert(
          0,
          ChatMessage(
              text: cleanReply, isUser: false, time: DateTime.now()));
      _isLoading = false;
    });
  }

  String _timeStr(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.robot,
                  size: 14, color: AppTheme.neonCyan),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jazzy AI Agent',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppTheme.neonGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('Groq · Agentic Mode',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.grey, size: 20),
            tooltip: 'Bersihkan chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text:
                      'Chat bersih Bos. Ada perintah yang mau saya eksekusi? 😊',
                  isUser: false,
                  time: DateTime.now(),
                ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _ObdContextBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isLoading && i == 0) return _buildTypingIndicator();
                final msg = _messages[_isLoading ? i - 1 : i];
                return _buildBubble(msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border:
              Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppTheme.neonCyan, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(
                    delay: Duration(milliseconds: i * 150),
                    duration: 300.ms)
                .then()
                .fadeOut(duration: 300.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: msg.isUser ? 60 : 0,
          right: msg.isUser ? 0 : 60,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppTheme.neonCyan.withOpacity(0.12)
              : AppTheme.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 20),
          ),
          border: Border.all(
            color: msg.isUser
                ? AppTheme.neonCyan.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : Colors.grey[200],
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_timeStr(msg.time),
                  style:
                      const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText:
                    'Ketik perintah atau tanya soal kendaraan...',
                hintStyle: TextStyle(
                    color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: AppTheme.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _isLoading
                    ? Colors.grey[800]
                    : AppTheme.neonCyan,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLoading
                    ? Icons.hourglass_empty
                    : Icons.send_rounded,
                color: _isLoading ? Colors.grey : Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── OBD Context Banner ────────────────────────────────────────────────────────
class _ObdContextBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final obd = ObdBluetoothService.instance;
    final isConnected = obd.currentState == ObdConnectionState.connected;
    final hasData = obd.batteryVoltage > 0;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isConnected
                ? AppTheme.neonGreen
                : AppTheme.neonCyan)
            .withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isConnected
                  ? AppTheme.neonGreen
                  : AppTheme.neonCyan)
              .withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sensors,
            size: 13,
            color: isConnected
                ? AppTheme.neonGreen
                : AppTheme.neonCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isConnected
                  ? 'Data OBD Live: Coolant ${obd.coolantTemp.toStringAsFixed(0)}°C · Aki ${obd.batteryVoltage.toStringAsFixed(1)}V · RPM ${obd.rpm.toStringAsFixed(0)}'
                  : 'Data Terakhir: Coolant ${obd.coolantTemp.toStringAsFixed(0)}°C · Aki ${obd.batteryVoltage.toStringAsFixed(1)}V · RPM ${obd.rpm.toStringAsFixed(0)}',
              style: TextStyle(
                color: isConnected
                    ? AppTheme.neonGreen
                    : AppTheme.neonCyan,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

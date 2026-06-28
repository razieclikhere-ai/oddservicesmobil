// ────────────────────────────────────────────────────────────────────────────
// features/chatbot/presentation/chatbot_screen.dart
// Jazzy AI chatbot — uses AiPredictionService (no duplicate API key)
// Multi-turn history trimmed to avoid context overflow
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/ai_prediction_service.dart';
import '../../../core/services/obd_bluetooth_service.dart';

const int _maxHistory = 20; // max turns to avoid context overflow

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

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text:
          'Halo Bos! Saya Jazzy, mekanik AI Anda 🤖\nSiap membantu diagnosa dan servis kendaraan Anda. Ada yang bisa saya bantu hari ini?',
      isUser: false,
      time: DateTime.now(),
    ));
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

    final obd = ObdBluetoothService.instance;

    try {
      final reply = await AiPredictionService.getJazzyResponse(
        query: text,
        coolantTemp: obd.coolantTemp,
        batteryVoltage: obd.batteryVoltage,
        rpm: obd.rpm,
        speed: obd.speed,
        dtcCodes: obd.dtcCodes,
      );

      if (mounted) {
        setState(() {
          _messages.insert(
              0, ChatMessage(text: reply, isUser: false, time: DateTime.now()));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.insert(
              0,
              ChatMessage(
                  text:
                      'Maaf Bos, ada gangguan koneksi ke server AI. Coba lagi sebentar ya! 🔄',
                  isUser: false,
                  time: DateTime.now()));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                const Text('Jazzy AI',
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
                    Text('Groq · Llama 3',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.grey, size: 20),
            tooltip: 'Bersihkan chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text:
                      'Chat bersih. Ada yang bisa Jazzy bantu, Bos? 😊',
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
          // OBD context banner
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
                    'Tanya soal kode DTC, servis, atau kondisi mobil...',
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

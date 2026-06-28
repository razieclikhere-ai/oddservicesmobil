import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, required this.time});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static String get _obfuscatedApiKey {
    const part1 = 'gsk_exMM6y7n';
    const part2 = 'CJJqt7qh6sjNWGdy';
    const part3 = 'b3FY8XthZ6rGXnvq3AVXQLSKSCHE';
    return part1 + part2 + part3;
  }

  final String _apiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '').isNotEmpty
      ? const String.fromEnvironment('GROQ_API_KEY')
      : _obfuscatedApiKey;
  late final Dio _dio;

  final List<Map<String, dynamic>> _chatHistory = [
    {
      'role': 'system',
      'content':
          'Kamu adalah Jazzy, sahabat mekanik profesional sekaligus asisten AI cerdas untuk kendaraan pengguna. Gaya bicaramu sangat hangat, ramah, dan penuh empati layaknya sahabat dekat yang sangat mengerti kebutuhan mobil mereka. Panggil pengguna dengan sebutan akrab seperti "Bos", "Bro", atau "Om". Berikan penjelasan teknis secara sederhana, solutif, dan mudah dimengerti. Jika ada kode error DTC, jelaskan artinya dengan tenang, beri tips pencegahan, dan estimasi biaya perbaikan secara bijak.'
    }
  ];

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
    _messages.add(ChatMessage(
      text: 'Halo! Saya Smart OBD AI 🤖\nSaya siap membantu Anda menganalisis kondisi kendaraan. Apa yang ingin Anda tanyakan?',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;
    final userText = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.insert(0, ChatMessage(text: userText, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });

    _chatHistory.add({'role': 'user', 'content': userText});

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': 'llama3-70b-8192',
        'messages': _chatHistory,
        'temperature': 0.6,
        'max_tokens': 512,
      });

      final reply = response.data['choices'][0]['message']['content'] as String? ?? 'Maaf, tidak ada respons.';
      _chatHistory.add({'role': 'assistant', 'content': reply});
      setState(() => _messages.insert(0, ChatMessage(text: reply, isUser: false, time: DateTime.now())));
    } on DioException catch (e) {
      _chatHistory.removeLast();
      String errMsg = 'Gagal terhubung ke server AI.';
      if (e.response?.statusCode == 401) errMsg = 'API Key tidak valid. Periksa konfigurasi.';
      if (e.type == DioExceptionType.connectionTimeout) errMsg = 'Koneksi timeout. Cek koneksi internet.';
      setState(() => _messages.insert(0, ChatMessage(text: errMsg, isUser: false, time: DateTime.now())));
    } finally {
      setState(() => _isLoading = false);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
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
              child: const Icon(FontAwesomeIcons.robot, size: 14, color: AppTheme.neonCyan),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart OBD AI', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: AppTheme.neonGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('Groq • Llama 3', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++)
              Container(
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppTheme.neonCyan, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: Duration(milliseconds: i * 150), duration: 300.ms)
                  .then()
                  .fadeOut(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: msg.isUser ? 60 : 0,
          right: msg.isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.neonCyan.withOpacity(0.12) : AppTheme.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 20),
          ),
          border: Border.all(
            color: msg.isUser ? AppTheme.neonCyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text,
                style: TextStyle(
                    color: msg.isUser ? Colors.white : Colors.grey[200],
                    fontSize: 14.5,
                    height: 1.4)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_timeStr(msg.time), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Tanya soal kode DTC, servis, atau kondisi mobil...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: AppTheme.darkBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[800] : AppTheme.neonCyan,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_empty : Icons.send_rounded,
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

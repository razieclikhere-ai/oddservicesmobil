import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // Groq API setup
  final String _apiKey = 'YOUR_GROQ_API_KEY_HERE';
  late final Dio _dio;
  
  // Chat history for context
  final List<Map<String, dynamic>> _chatHistory = [
    {
      'role': 'system', 
      'content': 'Kamu adalah asisten mekanik cerdas bernama "Smart OBD AI". Tugasmu adalah membantu pengguna menganalisis kesehatan mobil mereka dan memberikan tips perawatan secara ringkas, profesional, dan bersahabat.'
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
    ));
    // Initial welcome message from AI
    _messages.add(ChatMessage(
      text: 'Halo! Saya Smart OBD AI. Mobil apa yang ingin kita bahas kesehatannya hari ini?',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.insert(0, ChatMessage(text: userMessage, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });
    _controller.clear();

    try {
      // Append context about current vehicle if available
      final contextMessage = "Konteks saat ini: Kendaraan saya adalah Toyota Avanza 2020. Pertanyaan: $userMessage";
      _chatHistory.add({'role': 'user', 'content': contextMessage});
      
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'llama3-70b-8192',
          'messages': _chatHistory,
          'temperature': 0.5,
        },
      );

      if (response.statusCode == 200) {
        final assistantReply = response.data['choices'][0]['message']['content'] ?? 'Maaf, saya tidak mengerti.';
        _chatHistory.add({'role': 'assistant', 'content': assistantReply});
        
        setState(() {
          _messages.insert(0, ChatMessage(text: assistantReply, isUser: false, time: DateTime.now()));
        });
      } else {
        throw Exception('Failed to get response');
      }
    } catch (e) {
      _chatHistory.removeLast(); // Remove failed user message from history
      setState(() {
        _messages.insert(0, ChatMessage(text: 'Terjadi kesalahan koneksi ke server Groq AI.', isUser: false, time: DateTime.now()));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.robot, size: 16, color: AppTheme.neonCyan),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart OBD AI', style: TextStyle(fontSize: 16, color: Colors.white)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppTheme.neonGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('Online', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
              reverse: true,
              padding: const EdgeInsets.all(20.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('AI sedang menganalisis', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                  ),
                ],
              ).animate().fade().scale(),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.neonCyan.withOpacity(0.1) : AppTheme.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: Border.all(
            color: message.isUser ? AppTheme.neonCyan.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.grey[200],
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOut);
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan atau tanya kerusakan...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.darkBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.neonCyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

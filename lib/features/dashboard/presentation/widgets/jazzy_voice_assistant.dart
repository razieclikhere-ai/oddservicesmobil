import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/obd_bluetooth_service.dart';
import '../../../../core/services/ai_prediction_service.dart';

class JazzyVoiceAssistant extends StatefulWidget {
  const JazzyVoiceAssistant({Key? key}) : super(key: key);

  @override
  State<JazzyVoiceAssistant> createState() => _JazzyVoiceAssistantState();
}

class _JazzyVoiceAssistantState extends State<JazzyVoiceAssistant> {
  bool _isOpen = false;
  bool _isListening = false;
  bool _isThinking = false;
  String _jazzySpeech = "Halo Bos! Ada yang bisa Jazzy bantu soal kondisi Honda Jazz GE8 hari ini?";
  String _userSpeech = "";
  final TextEditingController _textController = TextEditingController();

  final List<String> _quickCommands = [
    "Bagaimana kondisi mobil?",
    "Cek tegangan aki",
    "Berapa suhu radiator?",
    "Kapan jadwal ganti oli?"
  ];

  void _toggleOpen() {
    setState(() {
      _isOpen = !_isOpen;
      if (!_isOpen) {
        _isListening = false;
        _isThinking = false;
      }
    });
  }

  Future<void> _handleCommand(String command) async {
    setState(() {
      _userSpeech = command;
      _isListening = false;
      _isThinking = true;
      _jazzySpeech = "...";
    });

    final obd = ObdBluetoothService.instance;
    final response = await AiPredictionService.getJazzyResponse(
      query: command,
      coolantTemp: obd.coolantTemp,
      batteryVoltage: obd.batteryVoltage,
      rpm: obd.rpm,
      speed: obd.speed,
      dtcCodes: obd.dtcCodes,
    );

    if (mounted) {
      setState(() {
        _isThinking = false;
        _jazzySpeech = response;
      });
    }
  }

  void _startListeningSim() {
    if (_isListening || _isThinking) return;

    setState(() {
      _isListening = true;
      _userSpeech = "Mendengarkan...";
    });

    // Simulate listening duration (2.5 seconds) then pick a random query or type custom
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isListening) {
        // Simple voice-to-text simulation logic
        final list = [
          "Bagaimana kondisi mobil?",
          "Cek tegangan aki",
          "Berapa suhu radiator?"
        ];
        final randomCommand = list[DateTime.now().second % list.length];
        _handleCommand(randomCommand);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Speech bubble popup ───────────────────────────────────────────────
        if (_isOpen)
          Container(
            width: 300,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.neonCyan.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(FontAwesomeIcons.robot, size: 14, color: AppTheme.neonCyan),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JAZZY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'AI Voice Assistant',
                              style: TextStyle(color: AppTheme.neonCyan, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: _toggleOpen,
                      ),
                    ],
                  ),
                ),

                // Dialog Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_userSpeech.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonCyan.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _userSpeech,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Jazzy Output
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.neonCyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isThinking
                                ? Row(
                                    children: List.generate(3, (index) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 2),
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.neonCyan,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                          .animate(onPlay: (c) => c.repeat(reverse: true))
                                          .scaleXY(
                                            begin: 0.5,
                                            end: 1.5,
                                            delay: Duration(milliseconds: index * 150),
                                            duration: 400.ms,
                                          );
                                    }),
                                  )
                                : Text(
                                    _jazzySpeech,
                                    style: const TextStyle(color: Colors.whiteEfficacy, fontSize: 13, height: 1.4),
                                  )
                                    .animate(key: ValueKey(_jazzySpeech))
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.05),
                          ),
                        ],
                      ),

                      // Soundwave Animation during speech / listening
                      if (_isListening || _isThinking) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(15, (index) {
                              final randomHeight = 8.0 + (index % 4) * 8.0;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 3,
                                height: _isListening ? randomHeight : 6,
                                decoration: BoxDecoration(
                                  color: _isListening ? AppTheme.neonCyan : AppTheme.neonOrange,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                                  .animate(onPlay: (c) => _isListening ? c.repeat(reverse: true) : c.stop())
                                  .scaleY(
                                    begin: 0.3,
                                    end: 1.5,
                                    delay: Duration(milliseconds: index * 40),
                                    duration: 350.ms,
                                    curve: Curves.easeInOut,
                                  );
                            }),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Text(
                        'Pilihan Perintah:',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      
                      // Quick command chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickCommands.map((cmd) {
                          return GestureDetector(
                            onTap: () => _handleCommand(cmd),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Text(
                                cmd.replaceAll("Bagaimana ", "").replaceAll("Berapa ", "").replaceAll("Kapan ", ""),
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Text input field
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: TextField(
                                controller: _textController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Tulis pertanyaan...',
                                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _handleCommand(val.trim());
                                    _textController.clear();
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Mic / Send button
                          GestureDetector(
                            onTap: () {
                              if (_textController.text.trim().isNotEmpty) {
                                _handleCommand(_textController.text.trim());
                                _textController.clear();
                              } else {
                                _startListeningSim();
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _isListening ? AppTheme.neonOrange : AppTheme.neonCyan,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _textController.text.trim().isNotEmpty ? Icons.send : Icons.mic,
                                size: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().scale(alignment: Alignment.bottomRight, duration: 250.ms, curve: Curves.easeOutBack),

        // ── Floating assistant button ─────────────────────────────────────────
        GestureDetector(
          onTap: _toggleOpen,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isOpen ? AppTheme.neonOrange : AppTheme.neonCyan,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isOpen ? AppTheme.neonOrange : AppTheme.neonCyan).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse waves
                if (!_isOpen)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonCyan.withOpacity(0.2)),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.4, 1.4), duration: 1200.ms)
                      .fadeOut(duration: 1200.ms),
                Icon(
                  FontAwesomeIcons.robot,
                  size: 20,
                  color: _isOpen ? AppTheme.neonOrange : AppTheme.neonCyan,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Add simple extension to support WhiteEfficacy styling safely
extension on TextStyle {
  TextStyle get whiteEfficacy => copyWith(color: Colors.white70);
}

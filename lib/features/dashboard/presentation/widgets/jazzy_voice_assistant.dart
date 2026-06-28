import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  bool _isSpeaking = false;
  String _statusText = "Ketuk untuk Bicara";
  
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("id-ID");
    _flutterTts.setSpeechRate(0.55); // Friendly conversational speed
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _statusText = "Jazzy Berbicara...";
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = "Ketuk untuk Bicara";
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = "Ketuk untuk Bicara";
        });
      }
    });
  }

  void _toggleOpen() {
    setState(() {
      _isOpen = !_isOpen;
      if (!_isOpen) {
        _isListening = false;
        _isThinking = false;
        _isSpeaking = false;
        _flutterTts.stop();
        _statusText = "Ketuk untuk Bicara";
      } else {
        // Start listening automatically when opened
        _startListeningSim();
      }
    });
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _handleCommand(String command) async {
    setState(() {
      _isListening = false;
      _isThinking = true;
      _statusText = "Jazzy Berpikir...";
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
      });
      // Speak out loud using TTS!
      _speak(response);
    }
  }

  void _startListeningSim() {
    if (_isListening || _isThinking || _isSpeaking) return;

    _flutterTts.stop();
    setState(() {
      _isListening = true;
      _statusText = "Mendengarkan...";
    });

    // Simulate listening duration (2.5 seconds) then pick a random query
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isListening) {
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
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _isListening
        ? AppTheme.neonCyan
        : _isThinking
            ? AppTheme.neonOrange
            : _isSpeaking
                ? AppTheme.neonGreen
                : Colors.white24;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Speech visualizer bar (NO CHAT BUBBLE!) ───────────────────────────
        if (_isOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: activeColor.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated soundwave bars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(8, (index) {
                    final randomHeight = 8.0 + (index % 3) * 6.0;
                    final isAnimating = _isListening || _isThinking || _isSpeaking;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 3,
                      height: isAnimating ? randomHeight : 4,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                        .animate(onPlay: (c) => isAnimating ? c.repeat(reverse: true) : c.stop())
                        .scaleY(
                          begin: 0.3,
                          end: 1.5,
                          delay: Duration(milliseconds: index * 60),
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                        );
                  }),
                ),
                const SizedBox(width: 14),
                // Status text
                Text(
                  _statusText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                // Interactive Mic Tap trigger
                GestureDetector(
                  onTap: () {
                    if (!_isListening && !_isThinking && !_isSpeaking) {
                      _startListeningSim();
                    } else {
                      _flutterTts.stop();
                      setState(() {
                        _isListening = false;
                        _isThinking = false;
                        _isSpeaking = false;
                        _statusText = "Ketuk untuk Bicara";
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: activeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSpeaking ? Icons.stop_rounded : Icons.mic,
                      size: 14,
                      color: activeColor,
                    ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/obd_bluetooth_service.dart';
import '../../../../core/services/ai_prediction_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

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
  String _statusText = "Ketuk untuk Aktifkan";

  late FlutterTts _flutterTts;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechInitialized = false;
  bool _alwaysOnMode = true; // Auto-listen loop after speaking

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.setSpeechRate(0.48); // Natural conversational speed
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.95); // Friendly female pitch adjustment

    try {
      final dynamic voices = await _flutterTts.getVoices;
      String? bestVoice;
      for (final v in voices) {
        final String name = (v['name'] as String? ?? '').toLowerCase();
        final String locale = (v['locale'] as String? ?? '').toLowerCase();
        if (locale.contains('id')) {
          // Prefer network-based high-quality neural voices
          if (name.contains('network') || name.contains('idc') || name.contains('knd')) {
            bestVoice = v['name'] as String;
            break;
          }
        }
      }
      if (bestVoice != null) {
        await _flutterTts.setVoice({"name": bestVoice, "locale": "id-ID"});
        _log.d("Jazzy: Selected neural voice: $bestVoice");
      }
    } catch (e) {
      _log.w("Jazzy: Error setting neural voice: $e");
    }

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _isListening = false;
          _statusText = "Jazzy Berbicara...";
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = "Mendengarkan...";
        });
        // After speaking, automatically return to listening mode if open
        if (_isOpen && _alwaysOnMode) {
          _startSpeechListening();
        }
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = "Ketuk untuk Bicara";
        });
        if (_isOpen && _alwaysOnMode) {
          _startSpeechListening();
        }
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speechToText.initialize(
        onStatus: (status) {
          _log.d("SpeechToText Status: $status");
          if (status == 'notListening') {
            if (mounted && _isOpen && !_isSpeaking && !_isThinking && _alwaysOnMode) {
              // Restart listening in always-on loop
              _startSpeechListening();
            }
          }
        },
        onError: (error) {
          _log.w("SpeechToText Error: ${error.errorMsg}");
          if (mounted && _isOpen && !_isSpeaking && !_isThinking && _alwaysOnMode) {
            // Retry listening
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _isOpen) _startSpeechListening();
            });
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _log.e("Speech initialization failed: $e");
    }
  }

  void _toggleOpen() async {
    if (!_isOpen) {
      // Check and request microphone permission
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin mikrofon ditolak. Silakan aktifkan di Pengaturan.'),
                backgroundColor: AppTheme.neonOrange,
              ),
            );
          }
          return;
        }
      }

      setState(() {
        _isOpen = true;
        _alwaysOnMode = true;
      });
      _startSpeechListening();
    } else {
      _closeAssistant();
    }
  }

  void _closeAssistant() {
    _flutterTts.stop();
    _speechToText.stop();
    setState(() {
      _isOpen = false;
      _isListening = false;
      _isThinking = false;
      _isSpeaking = false;
      _alwaysOnMode = false;
      _statusText = "Ketuk untuk Aktifkan";
    });
  }

  Future<void> _startSpeechListening() async {
    if (!_speechInitialized) {
      await _initSpeech();
    }
    if (_isSpeaking || _isThinking || !_isOpen) return;

    setState(() {
      _isListening = true;
      _statusText = "Mendengarkan...";
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted && result.finalResult) {
            final words = result.recognizedWords.trim();
            _processVoiceWords(words);
          }
        },
        localeId: "id-ID",
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (e) {
      _log.w("Error starting speech listen: $e");
    }
  }

  void _processVoiceWords(String rawWords) async {
    final words = rawWords.toLowerCase().trim();
    if (words.isEmpty) return;

    _log.i("Voice Input: $words");

    // Check for sleep/stop commands
    if (words.contains("tidur") || words.contains("stop mendengarkan") || words.contains("selesai")) {
      setState(() {
        _alwaysOnMode = false;
        _isListening = false;
      });
      await _speechToText.stop();
      await _speak("Siap. Saya istirahat dulu ya, Kak. Hati-hati di jalan!");
      _closeAssistant();
      return;
    }

    // Wake words check: "Hei Jazzy" or "Jazzy"
    bool hasWakeWord = words.contains("hei jazzy") || words.contains("jazzy");
    String command = rawWords;

    if (hasWakeWord) {
      // Strip wake word for cleaner processing
      command = rawWords
          .replaceAll(RegExp(r'hei jazzy', caseSensitive: false), '')
          .replaceAll(RegExp(r'jazzy', caseSensitive: false), '')
          .trim();
    }

    // If the assistant is open, we respond to any speech, but if they just said the wake word empty, say greeting
    if (command.isEmpty && hasWakeWord) {
      await _speak("Ya Kak? Ada yang bisa saya bantu untuk mobilnya?");
      return;
    }

    if (command.isNotEmpty) {
      await _handleVoiceCommand(command);
    }
  }

  Future<void> _handleVoiceCommand(String command) async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
      _isThinking = true;
      _statusText = "Jazzy Berpikir...";
    });

    final obd = ObdBluetoothService.instance;
    final isDriving = obd.speed > 0;

    final response = await AiPredictionService.getJazzyVoiceResponse(
      query: command,
      coolantTemp: obd.coolantTemp,
      batteryVoltage: obd.batteryVoltage,
      rpm: obd.rpm,
      speed: obd.speed,
      dtcCodes: obd.dtcCodes,
      isDriving: isDriving,
    );

    if (mounted && _isOpen) {
      setState(() {
        _isThinking = false;
      });
      await _speak(response);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isOpen) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
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
        // ── Speech visualizer bar ─────────────────────────────────────────────
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
                // Tap to Interrupt or Stop Speaking
                GestureDetector(
                  onTap: () {
                    if (_isSpeaking) {
                      _flutterTts.stop();
                      _startSpeechListening();
                    } else if (_isListening) {
                      _speechToText.stop();
                      setState(() {
                        _isListening = false;
                        _statusText = "Jazzy Siaga";
                      });
                    } else {
                      _startSpeechListening();
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

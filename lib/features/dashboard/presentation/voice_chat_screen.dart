import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/obd_bluetooth_service.dart';
import '../../../core/services/ai_prediction_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  String _transcript = "";
  String _aiResponse = "Halo! Saya Jazzy, asisten suara pintar Anda. Ada yang bisa saya bantu dengan kendaraan Anda hari ini?";
  String _statusText = "Ketuk Mikrofon untuk Berbicara";

  FlutterTts? _flutterTts;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechInitialized = false;
  bool _alwaysOnMode = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  @override
  void dispose() {
    try {
      _flutterTts?.stop();
      _speechToText.stop();
    } catch (_) {}
    super.dispose();
  }

  void _initTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage("id-ID");
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      await tts.setPitch(0.95);

      final dynamic voices = await tts.getVoices;
      String? bestVoice;
      if (voices != null) {
        for (final v in voices) {
          final String name = (v['name'] as String? ?? '').toLowerCase();
          final String locale = (v['locale'] as String? ?? '').toLowerCase();
          if (locale.contains('id')) {
            if (name.contains('network') || name.contains('idc') || name.contains('knd')) {
              bestVoice = v['name'] as String;
              break;
            }
          }
        }
      }
      if (bestVoice != null) {
        await tts.setVoice({"name": bestVoice, "locale": "id-ID"});
      }

      tts.setStartHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _isListening = false;
            _statusText = "Jazzy sedang berbicara...";
          });
        }
      });

      tts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _statusText = _alwaysOnMode ? "Mendengarkan..." : "Ketuk Mikrofon untuk Berbicara";
          });
          if (_alwaysOnMode) {
            _startSpeechListening();
          }
        }
      });

      tts.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _statusText = "Ketuk Mikrofon untuk Berbicara";
          });
          if (_alwaysOnMode) {
            _startSpeechListening();
          }
        }
      });
      _flutterTts = tts;
    } catch (e) {
      _log.e("VoiceChatScreen: TTS init failed: $e");
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            if (mounted && !_isSpeaking && !_isThinking && _alwaysOnMode) {
              _startSpeechListening();
            }
          }
        },
        onError: (error) {
          if (mounted && !_isSpeaking && !_isThinking && _alwaysOnMode) {
            Future.delayed(const Duration(milliseconds: 800), () {
              _startSpeechListening();
            });
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      _log.e("VoiceChatScreen: Speech init failed: $e");
    }
  }

  Future<void> _startSpeechListening() async {
    if (!_speechInitialized) {
      await _initSpeech();
    }
    final isMicGranted = await Permission.microphone.isGranted;
    if (!isMicGranted) {
      await Permission.microphone.request();
      return;
    }

    setState(() {
      _isListening = true;
      _statusText = "Mendengarkan...";
    });

    try {
      await _speechToText.listen(
        localeId: "id-ID",
        listenMode: ListenMode.confirmation,
        onResult: (result) {
          setState(() {
            _transcript = result.recognizedWords;
          });
          if (result.finalResult) {
            _handleUserSpeech(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      _log.e("VoiceChatScreen: Listen error: $e");
    }
  }

  Future<void> _stopSpeechListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
      _statusText = "Ketuk Mikrofon untuk Berbicara";
    });
  }

  Future<void> _handleUserSpeech(String command) async {
    if (command.trim().isEmpty) return;

    setState(() {
      _isListening = false;
      _isThinking = true;
      _statusText = "Jazzy sedang berpikir...";
    });

    try {
      final obd = ObdBluetoothService.instance;
      final isConnected = obd.currentState == ObdConnectionState.connected || obd.currentState == ObdConnectionState.simulating;
      final obdSummary = isConnected
          ? "Mobil terhubung. RPM: ${obd.rpm}, Kecepatan: ${obd.speed} km/h, Aki: ${obd.batteryVoltage}V, Coolant: ${obd.coolantTemp}°C, DTC: ${obd.dtcCodes}."
          : "Mobil tidak terhubung ke OBD. Aki: ${obd.batteryVoltage}V, Coolant: ${obd.coolantTemp}°C.";

      final reply = await AiPredictionService.getJazzyResponse(
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
          _aiResponse = reply;
        });
        await _flutterTts?.speak(reply);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _aiResponse = "Maaf, saya mengalami kendala koneksi AI.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.neonCyan;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Asisten Suara AI", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _alwaysOnMode ? Icons.autorenew : Icons.play_disabled,
              color: _alwaysOnMode ? primaryColor : Colors.grey,
            ),
            tooltip: _alwaysOnMode ? "Mode Selalu Mendengar Aktif" : "Mode Sekali Dengar Aktif",
            onPressed: () {
              setState(() {
                _alwaysOnMode = !_alwaysOnMode;
              });
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Transcript and response area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_transcript.isNotEmpty) ...[
                          Text(
                            "Anda:",
                            style: TextStyle(
                              color: isDark ? primaryColor : Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _transcript,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          "Jazzy AI:",
                          style: TextStyle(
                            color: AppTheme.neonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _aiResponse,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Animated wave indicator
              if (_isListening || _isThinking || _isSpeaking)
                Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 4,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _isThinking
                              ? AppTheme.neonOrange
                              : _isSpeaking
                                  ? AppTheme.neonGreen
                                  : primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scaleY(
                            begin: 0.3,
                            end: 1.2,
                            duration: Duration(milliseconds: 300 + (index * 80)),
                            curve: Curves.easeInOut,
                          ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 40),

              const SizedBox(height: 20),

              // Status message
              Text(
                _statusText,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[650],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              // Pulsing microphone button
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _stopSpeechListening();
                  } else {
                    _startSpeechListening();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isListening ? primaryColor : AppTheme.darkSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? Colors.white : primaryColor.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? primaryColor : Colors.black).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : FontAwesomeIcons.microphone,
                    color: _isListening ? Colors.black : primaryColor,
                    size: 28,
                  ),
                )
                    .animate(
                      target: _isListening ? 1.0 : 0.0,
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.08, 1.08),
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

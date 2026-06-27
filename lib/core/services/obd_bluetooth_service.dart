import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'ai_prediction_service.dart';
import 'notification_service.dart';

/// OBD connection mode:
/// - simulation: generates realistic fake sensor data (always available, great for testing)
/// - wifi: connects to ELM327 over TCP/WiFi on 192.168.0.10:35000 (common default IP)
enum ObdConnectionMode { simulation, wifi }

enum ObdConnectionState { disconnected, scanning, connecting, connected, simulating }

class ObdBluetoothService {
  static final ObdBluetoothService instance = ObdBluetoothService._internal();
  ObdBluetoothService._internal();

  final _stateController = StreamController<ObdConnectionState>.broadcast();
  Stream<ObdConnectionState> get connectionStateStream => _stateController.stream;

  ObdConnectionState _currentState = ObdConnectionState.disconnected;
  ObdConnectionState get currentState => _currentState;

  ObdConnectionMode _mode = ObdConnectionMode.simulation;
  ObdConnectionMode get mode => _mode;

  Socket? _socket;
  Timer? _simulationTimer;
  Timer? _dbWriteTimer;
  final _random = Random();
  bool _isRunning = false;

  // ── Live sensor values (public for UI) ────────────────────────────────────
  double coolantTemp    = 45.0;
  double batteryVoltage = 14.1;
  double rpm            = 0.0;
  double speed          = 0.0;
  double fuelTrim       = 0.0;
  String dtcCodes       = '';
  int    simulatedOdometer = 150000;

  void _updateState(ObdConnectionState s) {
    _currentState = s;
    _stateController.add(s);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Entry point — first tries WiFi, then falls back to simulation.
  Future<void> connectToObd({ObdConnectionMode preferredMode = ObdConnectionMode.wifi}) async {
    if (_isRunning) return;
    _isRunning = true;

    if (preferredMode == ObdConnectionMode.wifi) {
      await _connectWifi();
    } else {
      startSimulationMode();
    }
  }

  /// Force start simulation mode without trying hardware
  void startSimulationMode() {
    _socket?.destroy();
    _socket = null;
    _simulationTimer?.cancel();
    _isRunning = true;
    _mode = ObdConnectionMode.simulation;
    _updateState(ObdConnectionState.simulating);

    NotificationService.showInstantNotification(
      id: 1,
      title: '🔌 Smart OBD – Mode Simulasi Aktif',
      body: 'Tidak ada adaptor ELM327 terdeteksi. Data sensor disimulasikan untuk evaluasi AI.',
    );

    // Simulate sensor readings every 2 seconds
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) => _simulateTick());

    // Write to DB & call AI every 30 seconds
    _dbWriteTimer = Timer.periodic(const Duration(seconds: 30), (_) => _saveScanRecord());
  }

  void disconnect() {
    _isRunning = false;
    _simulationTimer?.cancel();
    _dbWriteTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _updateState(ObdConnectionState.disconnected);
  }

  // ── WiFi / TCP connection (ELM327 WiFi adapter) ────────────────────────────

  Future<void> _connectWifi({
    String host = '192.168.0.10',
    int port = 35000,
  }) async {
    _updateState(ObdConnectionState.scanning);
    try {
      _updateState(ObdConnectionState.connecting);
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _mode = ObdConnectionMode.wifi;
      _updateState(ObdConnectionState.connected);

      NotificationService.showInstantNotification(
        id: 1,
        title: '✅ ELM327 WiFi Terhubung',
        body: 'Adaptor OBD-II terhubung melalui WiFi di $host:$port',
      );

      _socket!.listen(
        _onWifiData,
        onError: (_) => startSimulationMode(),
        onDone:  ()  => startSimulationMode(),
      );

      // Init ELM327
      _sendCommand('ATZ');
      await Future.delayed(const Duration(milliseconds: 500));
      _sendCommand('ATE0'); // echo off
      _sendCommand('ATH0'); // headers off
      _sendCommand('ATSP0'); // auto protocol

      // Poll PIDs every 2 seconds
      _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPids());
      _dbWriteTimer    = Timer.periodic(const Duration(seconds: 30), (_) => _saveScanRecord());

    } catch (_) {
      // WiFi failed → simulation
      startSimulationMode();
    }
  }

  void _sendCommand(String cmd) {
    try {
      _socket?.write('$cmd\r');
    } catch (_) {}
  }

  final _wifiBuffer = StringBuffer();

  void _onWifiData(List<int> data) {
    final chunk = String.fromCharCodes(data);
    _wifiBuffer.write(chunk);
    if (_wifiBuffer.toString().contains('>')) {
      final response = _wifiBuffer.toString().replaceAll('>', '').trim();
      _parseObdResponse(response);
      _wifiBuffer.clear();
    }
  }

  void _pollPids() {
    _sendCommand('010C'); // RPM
    _sendCommand('010D'); // Speed
    _sendCommand('0105'); // Coolant temp
    _sendCommand('0142'); // Control module voltage
    _sendCommand('0106'); // Short term fuel trim
    _sendCommand('03');   // DTCs
  }

  void _parseObdResponse(String raw) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines) {
      if (line.length < 4) continue;
      final pid = line.substring(0, 4).toUpperCase();
      final bytes = line.substring(4).trim().split(' ');
      if (bytes.length < 2) continue;
      try {
        switch (pid) {
          case '410C': // RPM = (A*256 + B) / 4
            final a = int.parse(bytes[0], radix: 16);
            final b = int.parse(bytes[1], radix: 16);
            rpm = (a * 256 + b) / 4.0;
            break;
          case '410D': // Speed = A km/h
            speed = int.parse(bytes[0], radix: 16).toDouble();
            break;
          case '4105': // Coolant = A - 40
            coolantTemp = int.parse(bytes[0], radix: 16) - 40.0;
            break;
          case '4142': // Voltage = (A*256 + B) / 1000
            final a = int.parse(bytes[0], radix: 16);
            final b = int.parse(bytes[1], radix: 16);
            batteryVoltage = (a * 256 + b) / 1000.0;
            break;
          case '4106': // Fuel trim = (A - 128) * 100/128
            fuelTrim = (int.parse(bytes[0], radix: 16) - 128) * 100 / 128;
            break;
        }
      } catch (_) {}
    }
  }

  // ── Simulation tick ────────────────────────────────────────────────────────
  void _simulateTick() {
    // Warm up the engine gradually
    if (coolantTemp < 90) {
      coolantTemp += _random.nextDouble() * 1.2;
    } else {
      coolantTemp = 87 + _random.nextDouble() * 6;
    }

    // Realistic idle → driving cycle
    final driving = _random.nextDouble() > 0.4;
    rpm   = driving ? 1200 + _random.nextDouble() * 2000 : 750 + _random.nextDouble() * 100;
    speed = driving ? 20   + _random.nextDouble() * 80  : 0;

    batteryVoltage = driving ? 13.8 + _random.nextDouble() * 0.5
                             : 12.2 + _random.nextDouble() * 0.4;

    fuelTrim = -3.0 + _random.nextDouble() * 6.0;
    simulatedOdometer += (speed * (2 / 3600)).toInt();

    // Occasional alerts (5% chance)
    if (_random.nextDouble() < 0.05) {
      batteryVoltage = 11.5 + _random.nextDouble() * 0.4;
      dtcCodes = _random.nextBool() ? 'P0171' : 'P0300';
      NotificationService.showInstantNotification(
        id: 2,
        title: '⚠️ Peringatan Sensor OBD',
        body: dtcCodes == 'P0171'
            ? 'P0171 – Campuran bahan bakar terlalu kurus. Cek sensor O2 atau filter udara.'
            : 'P0300 – Misfire terdeteksi. Cek busi dan koil pengapian.',
      );
    } else {
      dtcCodes = '';
    }
  }

  // ── Database + AI ──────────────────────────────────────────────────────────
  Future<void> _saveScanRecord() async {
    await AppDatabase.insertScan({
      'uuid': const Uuid().v4(),
      'vehicle_uuid': 'default-honda-jazz-ge8',
      'scan_date': DateTime.now().toIso8601String(),
      'coolant_temp': coolantTemp,
      'battery_voltage': batteryVoltage,
      'rpm': rpm,
      'speed': speed,
      'fuel_trim': fuelTrim,
      'dtc_codes': dtcCodes,
      'notes': _mode == ObdConnectionMode.wifi ? 'WiFi ELM327 live data' : 'Simulated live data',
      'mileage': simulatedOdometer,
    });

    await AppDatabase.updateVehicleMileage('default-honda-jazz-ge8', simulatedOdometer);

    await AiPredictionService.predictAndSchedule(
      vehicleUuid: 'default-honda-jazz-ge8',
      vehicleName: 'Honda Jazz GE8',
      currentMileage: simulatedOdometer,
      coolantTemp: coolantTemp,
      batteryVoltage: batteryVoltage,
      rpm: rpm,
      fuelTrim: fuelTrim,
      dtcCodes: dtcCodes,
    );
  }
}

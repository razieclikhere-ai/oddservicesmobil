import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'ai_prediction_service.dart';
import 'notification_service.dart';

enum ObdConnectionState { disconnected, scanning, connecting, connected, simulating }

class ObdBluetoothService {
  static final ObdBluetoothService instance = ObdBluetoothService._internal();
  ObdBluetoothService._internal();

  final _stateController = StreamController<ObdConnectionState>.broadcast();
  Stream<ObdConnectionState> get connectionStateStream => _stateController.stream;

  ObdConnectionState _currentState = ObdConnectionState.disconnected;
  ObdConnectionState get currentState => _currentState;

  final _flutterBlueClassic = FlutterBlueClassic();
  BluetoothConnection? _connection;
  StreamSubscription<BluetoothDevice>? _scanSubscription;
  StreamSubscription<Uint8List>? _dataSubscription;
  Timer? _pollingTimer;
  Timer? _simulationTimer;
  Timer? _dbWriteTimer;
  final _random = Random();
  bool _isRunning = false;

  // ── Live sensor values ────────────────────────────────────────────────────
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

  // ── Connection flow ────────────────────────────────────────────────────────

  Future<void> connectToObd() async {
    if (_isRunning) return;
    _isRunning = true;

    _updateState(ObdConnectionState.scanning);

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied == true ||
        statuses[Permission.bluetoothConnect]?.isDenied == true) {
      startSimulationMode();
      return;
    }

    try {
      // 1. Try bonded (paired) devices first
      List<BluetoothDevice>? bonded = await _flutterBlueClassic.bondedDevices;
      BluetoothDevice? targetDevice;

      if (bonded != null) {
        for (var device in bonded) {
          final name = (device.name ?? device.address).toLowerCase();
          if (name.contains('obd') ||
              name.contains('elm327') ||
              name.contains('v-link') ||
              name.contains('diagnose') ||
              name.contains('link')) {
            targetDevice = device;
            break;
          }
        }
      }

      if (targetDevice != null) {
        await _connectToDevice(targetDevice);
        return;
      }

      // 2. If not found in bonded, scan for devices
      _flutterBlueClassic.startScan();
      _scanSubscription = _flutterBlueClassic.scanResults.listen((device) async {
        final name = (device.name ?? device.address).toLowerCase();
        if (name.contains('obd') ||
            name.contains('elm327') ||
            name.contains('v-link') ||
            name.contains('diagnose')) {
          _scanSubscription?.cancel();
          _flutterBlueClassic.stopScan();
          await _connectToDevice(device);
        }
      });

      // Auto-fallback if scanning takes too long (12 seconds)
      await Future.delayed(const Duration(seconds: 12));
      if (_currentState == ObdConnectionState.scanning) {
        _flutterBlueClassic.stopScan();
        startSimulationMode();
      }
    } catch (e) {
      startSimulationMode();
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateState(ObdConnectionState.connecting);
    try {
      // Connect via Bluetooth Classic SPP
      _connection = await _flutterBlueClassic.connect(device.address);

      if (_connection != null) {
        _updateState(ObdConnectionState.connected);

        NotificationService.showInstantNotification(
          id: 1,
          title: '✅ OBD-II Bluetooth Terhubung',
          body: 'Tersambung ke ${device.name ?? "OBD Adapter"} via Bluetooth Classic SPP.',
        );

        _startLiveDataReader();
      } else {
        startSimulationMode();
      }
    } catch (e) {
      startSimulationMode();
    }
  }

  void startSimulationMode() {
    _cleanupHardware();
    _isRunning = true;
    _updateState(ObdConnectionState.simulating);

    NotificationService.showInstantNotification(
      id: 1,
      title: '🔌 Mode Simulasi OBD Aktif',
      body: 'Tidak ada adaptor OBD Bluetooth Classic terdeteksi. Data disimulasikan.',
    );

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) => _simulateTick());
    _dbWriteTimer = Timer.periodic(const Duration(seconds: 30), (_) => _saveScanRecord());
  }

  void disconnect() {
    _isRunning = false;
    _cleanupHardware();
    _simulationTimer?.cancel();
    _dbWriteTimer?.cancel();
    _updateState(ObdConnectionState.disconnected);
  }

  void _cleanupHardware() {
    _scanSubscription?.cancel();
    _dataSubscription?.cancel();
    _pollingTimer?.cancel();
    try {
      _connection?.dispose();
    } catch (_) {}
    _connection = null;
  }

  // ── Hardware data receiver & parser ────────────────────────────────────────

  final StringBuffer _rxBuffer = StringBuffer();

  void _startLiveDataReader() {
    if (_connection == null) return;

    // 1. Listen for serial responses from ELM327
    final input = _connection!.input;
    if (input != null) {
      _dataSubscription = input.listen((data) {
        // Use String.fromCharCodes to prevent FormatException from raw/corrupted bytes
        final chunk = String.fromCharCodes(data);
        _rxBuffer.write(chunk);
        
        // ELM327 prompt char '>' indicates it finished processing command(s)
        if (_rxBuffer.toString().contains('>')) {
          final response = _rxBuffer.toString().replaceAll('>', '').trim();
          _parseObdResponse(response);
          _rxBuffer.clear();
        }
      }, onError: (_) => startSimulationMode(), onDone: () => startSimulationMode());
    } else {
      startSimulationMode();
      return;
    }

    // 2. Send initialization commands (slower intervals to allow cheap OBD clones to boot)
    _sendCmd('ATZ'); // Reset
    Future.delayed(const Duration(milliseconds: 1000), () => _sendCmd('ATE0')); // Echo off
    Future.delayed(const Duration(milliseconds: 1800), () => _sendCmd('ATH0')); // Headers off
    Future.delayed(const Duration(milliseconds: 2600), () => _sendCmd('ATSP0')); // Auto Protocol
    Future.delayed(const Duration(milliseconds: 3400), () => _sendCmd('ATRV')); // Read voltage

    // 3. Setup polling loop every 2 seconds for active sensor readings
    int pollIndex = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentState != ObdConnectionState.connected) {
        timer.cancel();
        return;
      }

      // Rotate through standard OBD-II PIDs
      switch (pollIndex) {
        case 0:
          _sendCmd('010C'); // RPM
          break;
        case 1:
          _sendCmd('010D'); // Speed
          break;
        case 2:
          _sendCmd('0105'); // Coolant Temp
          break;
        case 3:
          _sendCmd('ATRV'); // Battery voltage
          break;
        case 4:
          _sendCmd('0106'); // Fuel Trim
          break;
        case 5:
          _sendCmd('03'); // Get stored DTC codes
          break;
      }
      pollIndex = (pollIndex + 1) % 6;
    });

    _dbWriteTimer = Timer.periodic(const Duration(seconds: 30), (_) => _saveScanRecord());
  }

  void _sendCmd(String cmd) {
    if (_connection != null) {
      try {
        _connection!.writeString('$cmd\r');
      } catch (_) {}
    }
  }

  void _parseObdResponse(String raw) {
    final lines = raw.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines) {
      // 1. Parse battery voltage (e.g. "14.2V" or "12.5")
      if (line.contains('.') && (line.contains('V') || line.endsWith('V') || double.tryParse(line.replaceAll('V', '').trim()) != null)) {
        final val = double.tryParse(line.replaceAll('V', '').trim());
        if (val != null) {
          batteryVoltage = val;
        }
        continue;
      }

      // 2. Strip all spaces for clean hex parsing (supports "41 0C 0F A0" and "410C0FA0")
      final clean = line.replaceAll(' ', '').toUpperCase();
      if (clean.length < 4) continue;

      try {
        if (clean.startsWith('410C')) {
          // RPM = ((A*256) + B) / 4
          final data = clean.substring(4);
          if (data.length >= 4) {
            final a = int.parse(data.substring(0, 2), radix: 16);
            final b = int.parse(data.substring(2, 4), radix: 16);
            rpm = (a * 256 + b) / 4.0;
          }
        } else if (clean.startsWith('410D')) {
          // Speed = A km/h
          final data = clean.substring(4);
          if (data.length >= 2) {
            speed = int.parse(data.substring(0, 2), radix: 16).toDouble();
          }
        } else if (clean.startsWith('4105')) {
          // Coolant Temp = A - 40
          final data = clean.substring(4);
          if (data.length >= 2) {
            coolantTemp = (int.parse(data.substring(0, 2), radix: 16) - 40).toDouble();
          }
        } else if (clean.startsWith('4106')) {
          // Fuel Trim = (A - 128) * 100/128
          final data = clean.substring(4);
          if (data.length >= 2) {
            fuelTrim = (int.parse(data.substring(0, 2), radix: 16) - 128) * 100 / 128;
          }
        } else if (clean.startsWith('43')) {
          // DTC response
          final data = clean.substring(2);
          if (data.length >= 4 && data.substring(0, 4) != '0000') {
            dtcCodes = 'P${data.substring(0, 4)}';
          } else {
            dtcCodes = '';
          }
        }
      } catch (_) {}
    }
  }

  // ── Simulation tick ────────────────────────────────────────────────────────

  void _simulateTick() {
    if (coolantTemp < 90) {
      coolantTemp += _random.nextDouble() * 1.2;
    } else {
      coolantTemp = 87 + _random.nextDouble() * 6;
    }

    final driving = _random.nextDouble() > 0.4;
    rpm = driving ? 1200 + _random.nextDouble() * 2000 : 750 + _random.nextDouble() * 100;
    speed = driving ? 20 + _random.nextDouble() * 80 : 0;
    batteryVoltage = driving ? 13.8 + _random.nextDouble() * 0.5 : 12.2 + _random.nextDouble() * 0.4;
    fuelTrim = -3.0 + _random.nextDouble() * 6.0;
    simulatedOdometer += (speed * (2 / 3600)).toInt();

    if (_random.nextDouble() < 0.05) {
      batteryVoltage = 11.5 + _random.nextDouble() * 0.4;
      dtcCodes = _random.nextBool() ? 'P0171' : 'P0300';
      NotificationService.showInstantNotification(
        id: 2,
        title: '⚠️ Peringatan Sensor OBD',
        body: dtcCodes == 'P0171'
            ? 'P0171 – Campuran bahan bakar terlalu kurus. Cek filter udara.'
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
      'notes': _currentState == ObdConnectionState.connected ? 'OBD-II Bluetooth Classic live data' : 'Simulated live data',
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

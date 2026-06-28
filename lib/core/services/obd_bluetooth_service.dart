// ────────────────────────────────────────────────────────────────────────────
// core/services/obd_bluetooth_service.dart
// Fixed: proper lifecycle, reconnect logic, no hardcoded vehicle UUID
// ────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'ai_prediction_service.dart';
import 'notification_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

enum ObdConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  simulating,
}

class ObdBluetoothService {
  static final ObdBluetoothService instance = ObdBluetoothService._internal();

  ObdBluetoothService._internal();

  // ── Streams ──────────────────────────────────────────────────────────────
  final _stateController =
      StreamController<ObdConnectionState>.broadcast();
  Stream<ObdConnectionState> get connectionStateStream =>
      _stateController.stream;

  ObdConnectionState _currentState = ObdConnectionState.disconnected;
  ObdConnectionState get currentState => _currentState;

  // ── Internal state ────────────────────────────────────────────────────────
  final _flutterBlueClassic = FlutterBlueClassic();
  BluetoothConnection? _connection;
  StreamSubscription<BluetoothDevice>? _scanSubscription;
  StreamSubscription<Uint8List>? _dataSubscription;
  Timer? _pollingTimer;
  Timer? _dbWriteTimer;
  bool _isRunning = false;

  // Active vehicle UUID — set by app when user switches vehicle
  String activeVehicleUuid = 'default-honda-jazz-ge8';
  String activeVehicleName = 'Honda Jazz GE8';

  // ── Live sensor values ────────────────────────────────────────────────────
  double coolantTemp    = 0.0;
  double batteryVoltage = 0.0;
  double rpm            = 0.0;
  double speed          = 0.0;
  double fuelTrim       = 0.0;
  String dtcCodes       = '';
  int    currentOdometer = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Load the last saved OBD session from database.
  Future<void> loadLastSavedData([String? vehicleUuid]) async {
    final uuid = vehicleUuid ?? activeVehicleUuid;
    try {
      final list = await AppDatabase.getScans(uuid);
      if (list.isNotEmpty) {
        final last = list.first;
        coolantTemp    = (last['coolant_temp']    as num?)?.toDouble() ?? 0.0;
        batteryVoltage = (last['battery_voltage'] as num?)?.toDouble() ?? 0.0;
        rpm            = (last['rpm']             as num?)?.toDouble() ?? 0.0;
        speed          = (last['speed']           as num?)?.toDouble() ?? 0.0;
        fuelTrim       = (last['fuel_trim']       as num?)?.toDouble() ?? 0.0;
        dtcCodes       = last['dtc_codes']        as String? ?? '';
        currentOdometer = last['mileage']         as int?    ?? 0;
        if (!_stateController.isClosed) {
          _stateController.add(_currentState);
        }
        _log.d('OBD: Loaded last saved scan for $uuid');
      }
    } catch (e) {
      _log.w('OBD: Could not load last saved data: $e');
    }
  }

  Future<void> connectToObd() async {
    if (_isRunning) return;
    _isRunning = true;
    _updateState(ObdConnectionState.scanning);

    // Request permissions
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied == true ||
        statuses[Permission.bluetoothConnect]?.isDenied == true) {
      _log.w('OBD: Bluetooth permissions denied');
      _setDisconnected();
      return;
    }

    try {
      // 1. Try bonded (paired) devices first
      final bonded = await _flutterBlueClassic.bondedDevices;
      BluetoothDevice? targetDevice;

      if (bonded != null) {
        for (final device in bonded) {
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

      // 2. Scan for new devices (timeout: 12 s)
      _flutterBlueClassic.startScan();
      _scanSubscription =
          _flutterBlueClassic.scanResults.listen((device) async {
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

      await Future.delayed(const Duration(seconds: 12));
      if (_currentState == ObdConnectionState.scanning) {
        _flutterBlueClassic.stopScan();
        _log.i('OBD: Scan timeout — no device found');
        _setDisconnected();
      }
    } catch (e, st) {
      _log.e('OBD: connectToObd error', error: e, stackTrace: st);
      _setDisconnected();
    }
  }

  void disconnect() => _setDisconnected();

  void startSimulationMode() {
    _cleanupHardware();
    _isRunning = false;
    coolantTemp    = 85.0;
    batteryVoltage = 13.5;
    rpm            = 1500.0;
    speed          = 60.0;
    fuelTrim       = 2.5;
    dtcCodes       = '';
    _updateState(ObdConnectionState.simulating);
    _log.i('OBD: Simulation mode started');
  }

  /// Must be called when the app is disposed (rarely needed — singleton lives
  /// for app lifetime, but useful in tests).
  void dispose() {
    _cleanupHardware();
    _stateController.close();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _updateState(ObdConnectionState s) {
    _currentState = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateState(ObdConnectionState.connecting);
    try {
      _connection = await _flutterBlueClassic.connect(device.address);
      if (_connection != null) {
        _updateState(ObdConnectionState.connected);
        NotificationService.showInstantNotification(
          id: 1,
          title: '✅ OBD-II Terhubung',
          body:
              'Tersambung ke ${device.name ?? "OBD Adapter"} via Bluetooth Classic.',
        );
        _startLiveDataReader();
        _log.i('OBD: Connected to ${device.name ?? device.address}');
      } else {
        _log.w('OBD: Connection returned null');
        _setDisconnected();
      }
    } catch (e, st) {
      _log.e('OBD: _connectToDevice error', error: e, stackTrace: st);
      _setDisconnected();
    }
  }

  void _setDisconnected() {
    _cleanupHardware();
    _isRunning = false;
    _updateState(ObdConnectionState.disconnected);
    // Show last saved data when going offline
    loadLastSavedData();
  }

  void _cleanupHardware() {
    _scanSubscription?.cancel();
    _dataSubscription?.cancel();
    _pollingTimer?.cancel();
    _dbWriteTimer?.cancel();
    _scanSubscription = null;
    _dataSubscription = null;
    _pollingTimer = null;
    _dbWriteTimer = null;
    try {
      _connection?.dispose();
    } catch (_) {}
    _connection = null;
  }

  // ── Data reader / parser ──────────────────────────────────────────────────

  final _rxBuffer = StringBuffer();

  void _startLiveDataReader() {
    if (_connection == null) return;
    final input = _connection!.input;
    if (input == null) {
      _setDisconnected();
      return;
    }

    _dataSubscription = input.listen(
      (data) {
        _rxBuffer.write(String.fromCharCodes(data));
        if (_rxBuffer.toString().contains('>')) {
          final response =
              _rxBuffer.toString().replaceAll('>', '').trim();
          _rxBuffer.clear();
          _parseObdResponse(response);
        }
      },
      onError: (e) {
        _log.w('OBD: Stream error: $e');
        _setDisconnected();
      },
      onDone: () {
        _log.i('OBD: Stream closed by device');
        _setDisconnected();
      },
    );

    // ELM327 init sequence
    _sendCmd('ATZ');
    Future.delayed(const Duration(milliseconds: 1000), () => _sendCmd('ATE0'));
    Future.delayed(const Duration(milliseconds: 1800), () => _sendCmd('ATH0'));
    Future.delayed(const Duration(milliseconds: 2600), () => _sendCmd('ATSP0'));
    Future.delayed(const Duration(milliseconds: 3400), () => _sendCmd('ATRV'));

    // Polling loop — rotates through PIDs every 2 s
    int pollIndex = 0;
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentState != ObdConnectionState.connected) {
        timer.cancel();
        return;
      }
      switch (pollIndex) {
        case 0: _sendCmd('010C'); break; // RPM
        case 1: _sendCmd('010D'); break; // Speed
        case 2: _sendCmd('0105'); break; // Coolant Temp
        case 3: _sendCmd('ATRV'); break; // Battery voltage
        case 4: _sendCmd('0106'); break; // Short-term Fuel Trim
        case 5: _sendCmd('03');   break; // DTC codes
      }
      pollIndex = (pollIndex + 1) % 6;
    });

    // Persist to DB every 30 s
    _dbWriteTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _saveScanRecord());
  }

  void _sendCmd(String cmd) {
    if (_connection != null) {
      try {
        _connection!.writeString('$cmd\r');
      } catch (e) {
        _log.w('OBD: sendCmd "$cmd" failed: $e');
      }
    }
  }

  void _parseObdResponse(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      // Battery voltage (e.g. "14.2V")
      if (line.contains('.') &&
          (line.endsWith('V') ||
              double.tryParse(line.replaceAll('V', '').trim()) != null)) {
        final val =
            double.tryParse(line.replaceAll('V', '').trim());
        if (val != null && val > 0) batteryVoltage = val;
        continue;
      }

      final clean = line.replaceAll(' ', '').toUpperCase();
      if (clean.length < 4) continue;

      try {
        if (clean.startsWith('410C') && clean.length >= 8) {
          final a = int.parse(clean.substring(4, 6), radix: 16);
          final b = int.parse(clean.substring(6, 8), radix: 16);
          rpm = (a * 256 + b) / 4.0;
        } else if (clean.startsWith('410D') && clean.length >= 6) {
          speed = int.parse(clean.substring(4, 6), radix: 16).toDouble();
        } else if (clean.startsWith('4105') && clean.length >= 6) {
          coolantTemp =
              (int.parse(clean.substring(4, 6), radix: 16) - 40).toDouble();
        } else if (clean.startsWith('4106') && clean.length >= 6) {
          fuelTrim =
              (int.parse(clean.substring(4, 6), radix: 16) - 128) * 100 / 128;
        } else if (clean.startsWith('43') && clean.length >= 6) {
          final data = clean.substring(2);
          dtcCodes = (data.length >= 4 && data.substring(0, 4) != '0000')
              ? 'P${data.substring(0, 4)}'
              : '';
        }
      } catch (e) {
        _log.v('OBD: parse error on "$clean": $e');
      }
    }
  }

  Future<void> _saveScanRecord() async {
    if (_currentState != ObdConnectionState.connected) return;
    try {
      await AppDatabase.insertScan({
        'uuid': const Uuid().v4(),
        'vehicle_uuid': activeVehicleUuid,
        'scan_date': DateTime.now().toIso8601String(),
        'coolant_temp': coolantTemp,
        'battery_voltage': batteryVoltage,
        'rpm': rpm,
        'speed': speed,
        'fuel_trim': fuelTrim,
        'dtc_codes': dtcCodes,
        'notes': 'OBD-II Bluetooth live data',
        'mileage': currentOdometer,
      });

      await AppDatabase.updateVehicleMileage(
          activeVehicleUuid, currentOdometer);

      await AiPredictionService.predictAndSchedule(
        vehicleUuid: activeVehicleUuid,
        vehicleName: activeVehicleName,
        currentMileage: currentOdometer,
        coolantTemp: coolantTemp,
        batteryVoltage: batteryVoltage,
        rpm: rpm,
        fuelTrim: fuelTrim,
        dtcCodes: dtcCodes,
      );
    } catch (e, st) {
      _log.e('OBD: _saveScanRecord error', error: e, stackTrace: st);
    }
  }
}

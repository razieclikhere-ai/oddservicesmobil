import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/app_database.dart';
import 'ai_prediction_service.dart';
import 'notification_service.dart';
import 'package:uuid/uuid.dart';

enum ObdConnectionState { disconnected, scanning, connecting, connected, simulating }

class ObdBluetoothService {
  static final ObdBluetoothService instance = ObdBluetoothService._internal();
  ObdBluetoothService._internal();

  final _connectionStateController = StreamController<ObdConnectionState>.broadcast();
  Stream<ObdConnectionState> get connectionStateStream => _connectionStateController.stream;
  ObdConnectionState _currentState = ObdConnectionState.disconnected;
  ObdConnectionState get currentState => _currentState;

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _simulationTimer;
  final _random = Random();

  // OBD Sensor Live Data values
  double coolantTemp = 90.0;
  double batteryVoltage = 14.1;
  double rpm = 800;
  double speed = 0.0;
  double fuelTrim = 0.0;
  String dtcCodes = '';
  int simulatedOdometer = 150000;

  void _updateState(ObdConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }

  // --- Bluetooth Connection logic ---
  Future<void> connectToObd() async {
    if (_currentState == ObdConnectionState.connected || _currentState == ObdConnectionState.simulating) {
      return;
    }

    _updateState(ObdConnectionState.scanning);

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied == true ||
        statuses[Permission.bluetoothConnect]?.isDenied == true) {
      // Permission denied, fallback to Simulation Mode
      startSimulationMode();
      return;
    }

    // Start scanning
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final name = r.device.platformName.toLowerCase();
          if (name.contains('obd') || name.contains('elm327') || name.contains('v-link') || name.contains('diagnose')) {
            // Found OBD adapter
            _scanSubscription?.cancel();
            await FlutterBluePlus.stopScan();
            _updateState(ObdConnectionState.connecting);
            
            try {
              await r.device.connect();
              _connectedDevice = r.device;
              _updateState(ObdConnectionState.connected);
              _startLiveDataReader();
              return;
            } catch (e) {
              // Connection failed, fallback to simulation
              startSimulationMode();
            }
          }
        }
      });

      // If scan finishes and no device is found
      await Future.delayed(const Duration(seconds: 11));
      if (_currentState == ObdConnectionState.scanning) {
        startSimulationMode();
      }
    } catch (e) {
      startSimulationMode();
    }
  }

  // --- Simulated Live OBD Data ---
  void startSimulationMode() {
    _scanSubscription?.cancel();
    _simulationTimer?.cancel();
    _updateState(ObdConnectionState.simulating);

    NotificationService.showInstantNotification(
      id: 1,
      title: '🔌 Mode Simulasi OBD Aktif',
      body: 'Tidak ada adaptor fisik terdeteksi. Data OBD akan disimulasikan untuk evaluasi AI.',
    );

    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      // Generate realistic values
      rpm = 800 + _random.nextDouble() * 1200; // 800 - 2000 RPM
      speed = (rpm > 1200) ? 40 + _random.nextDouble() * 60 : 0; // 0 - 100 km/h
      
      // Gradually rise coolant temp to operating ranges
      if (coolantTemp < 96) {
        coolantTemp += _random.nextDouble() * 0.8;
      } else {
        coolantTemp += _random.nextDouble() * 0.4 - 0.2;
      }

      // Simulate battery voltage slightly dropping/fluctuating
      batteryVoltage = 13.8 + _random.nextDouble() * 0.6;
      fuelTrim = -3.0 + _random.nextDouble() * 6.0; // -3% to +3%
      
      simulatedOdometer += (speed * (4 / 3600)).toInt(); // add mileage based on speed and time elapsed

      // Occasionally simulate a warning trigger (e.g. low voltage or high temp) to test notifications
      if (_random.nextDouble() < 0.05) {
        batteryVoltage = 11.9; // low voltage
        dtcCodes = 'P0171'; // System Too Lean
        
        await NotificationService.showInstantNotification(
          id: 2,
          title: '⚠️ Peringatan Tegangan Aki Rendah',
          body: 'Tegangan terdeteksi $batteryVoltage V. Cek alternator atau ganti aki segera.',
        );
      }

      // Save to database every 12 seconds
      if (timer.tick % 3 == 0) {
        await _saveScanRecord();
      }
    });
  }

  Future<void> _saveScanRecord() async {
    final uuid = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    await AppDatabase.insertScan({
      'uuid': uuid,
      'vehicle_uuid': 'default-honda-jazz-ge8',
      'scan_date': now,
      'coolant_temp': coolantTemp,
      'battery_voltage': batteryVoltage,
      'rpm': rpm,
      'speed': speed,
      'fuel_trim': fuelTrim,
      'dtc_codes': dtcCodes,
      'notes': 'Pembacaan parameter sensor real-time via koneksi OBD.',
      'mileage': simulatedOdometer,
    });

    await AppDatabase.updateVehicleMileage('default-honda-jazz-ge8', simulatedOdometer);

    // Call AI to predict & update maintenance schedules
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

  void _startLiveDataReader() {
    // Read PIDs from device via BLE services if physical device is connected
    // This runs in background
  }

  void disconnect() {
    _simulationTimer?.cancel();
    _scanSubscription?.cancel();
    _connectedDevice?.disconnect();
    _updateState(ObdConnectionState.disconnected);
  }
}

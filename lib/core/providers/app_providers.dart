// ────────────────────────────────────────────────────────────────────────────
// core/providers/app_providers.dart
// All Riverpod providers — active vehicle, schedules, scans, OBD state
// ────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../services/obd_bluetooth_service.dart';

// ── SharedPreferences ─────────────────────────────────────────────────────────
final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

// ── Active Vehicle UUID ───────────────────────────────────────────────────────
const _kActiveVehicleKey = 'active_vehicle_uuid';

class ActiveVehicleNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final uuid = prefs.getString(_kActiveVehicleKey) ?? 'default-honda-jazz-ge8';
    // Sync OBD service
    _syncObd(uuid);
    return uuid;
  }

  Future<void> setActive(String uuid) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(_kActiveVehicleKey, uuid);
    _syncObd(uuid);
    state = AsyncData(uuid);
    // Reload dependent data
    ref.invalidate(vehiclesProvider);
    ref.invalidate(schedulesProvider);
    ref.invalidate(serviceLogsProvider);
    ref.invalidate(recentScansProvider);
  }

  void _syncObd(String uuid) {
    final obd = ObdBluetoothService.instance;
    obd.activeVehicleUuid = uuid;
    // Reload last scan for new active vehicle
    obd.loadLastSavedData(uuid);
  }
}

final activeVehicleProvider =
    AsyncNotifierProvider<ActiveVehicleNotifier, String>(
  ActiveVehicleNotifier.new,
);

// ── Convenience getter (sync, throws if not loaded yet) ──────────────────────
final activeVehicleUuidProvider = Provider<String>((ref) {
  return ref.watch(activeVehicleProvider).valueOrNull ??
      'default-honda-jazz-ge8';
});

// ── Vehicles list ─────────────────────────────────────────────────────────────
final vehiclesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (_) => AppDatabase.getVehicles(),
);

// ── Schedules for active vehicle ──────────────────────────────────────────────
final schedulesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uuid = ref.watch(activeVehicleUuidProvider);
  return AppDatabase.getSchedules(uuid);
});

// ── Service logs for active vehicle ──────────────────────────────────────────
final serviceLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uuid = ref.watch(activeVehicleUuidProvider);
  return AppDatabase.getServiceLogs(uuid);
});

// ── Recent OBD scans (last 3) ─────────────────────────────────────────────────
final recentScansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uuid = ref.watch(activeVehicleUuidProvider);
  final scans = await AppDatabase.getScans(uuid, limit: 3);
  return scans;
});

// ── Full scan history ─────────────────────────────────────────────────────────
final scanHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uuid = ref.watch(activeVehicleUuidProvider);
  return AppDatabase.getScans(uuid, limit: 200);
});

// ── OBD connection state (Stream-based) ──────────────────────────────────────
final obdConnectionStateProvider =
    StreamProvider<ObdConnectionState>((ref) {
  return ObdBluetoothService.instance.connectionStateStream;
});

// ── Inspection problems count for active vehicle ─────────────────────────────
final inspectionProblemsCountProvider =
    FutureProvider<int>((ref) async {
  final uuid = ref.watch(activeVehicleUuidProvider);
  final prefs = await SharedPreferences.getInstance();
  final savedJson = prefs.getString('inspection_$uuid');
  if (savedJson != null) {
    try {
      final Map<String, dynamic> data = jsonDecode(savedJson);
      // CheckStatus.problem.index is 3
      return data.values.where((v) => v == 3).length;
    } catch (_) {}
  }
  return 0;
});

// ── Bottom Navigation Tab Index Provider ─────────────────────────────────────
final dashboardTabIndexProvider = StateProvider<int>((ref) => 0);

// ── Selected Servis Tab Index Provider (0 = Jadwal AI, 1 = Riwayat Catatan) ────
final selectedServisTabProvider = StateProvider<int>((ref) => 0);

// ── Retrieve API Key dynamically (SharedPreferences first, then compile time) ─
Future<String> getEffectiveApiKey() async {
  final prefs = await SharedPreferences.getInstance();
  final userKey = prefs.getString('user_groq_api_key');
  if (userKey != null && userKey.trim().isNotEmpty) {
    return userKey.trim();
  }
  return const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
}

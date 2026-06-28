// ────────────────────────────────────────────────────────────────────────────
// core/database/app_database.dart
// v3 — Indexes, FK enforcement, typed helpers, full migrations
// ────────────────────────────────────────────────────────────────────────────
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'smart_obd.db');
    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        // Enable foreign key enforcement
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedDefaults(db);
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicles (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid                TEXT    NOT NULL UNIQUE,
        name                TEXT    NOT NULL,
        brand               TEXT    NOT NULL,
        model               TEXT    NOT NULL,
        year                INTEGER NOT NULL,
        engine_type         TEXT    NOT NULL,
        fuel_type           TEXT    NOT NULL,
        transmission_type   TEXT    NOT NULL,
        vin                 TEXT,
        current_mileage     INTEGER DEFAULT 0,
        license_plate       TEXT,
        color               TEXT,
        notes               TEXT,
        created_at          TEXT    NOT NULL,
        updated_at          TEXT    NOT NULL,
        is_active           INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_schedules (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid                    TEXT    NOT NULL UNIQUE,
        vehicle_uuid            TEXT    NOT NULL,
        service_name            TEXT    NOT NULL,
        description             TEXT,
        interval_mileage        INTEGER NOT NULL,
        interval_months         INTEGER NOT NULL,
        last_service_mileage    INTEGER DEFAULT 0,
        last_service_date       TEXT,
        next_predicted_date     TEXT,
        next_predicted_mileage  INTEGER,
        is_enabled              INTEGER DEFAULT 1,
        FOREIGN KEY (vehicle_uuid) REFERENCES vehicles (uuid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS obd_scans (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid            TEXT    NOT NULL UNIQUE,
        vehicle_uuid    TEXT    NOT NULL,
        scan_date       TEXT    NOT NULL,
        coolant_temp    REAL,
        battery_voltage REAL,
        rpm             REAL,
        speed           REAL,
        fuel_trim       REAL,
        dtc_codes       TEXT,
        notes           TEXT,
        mileage         INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_uuid) REFERENCES vehicles (uuid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_logs (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid                TEXT    NOT NULL UNIQUE,
        vehicle_uuid        TEXT    NOT NULL,
        service_date        TEXT    NOT NULL,
        service_type        TEXT    NOT NULL,
        oil_brand           TEXT,
        current_mileage     INTEGER NOT NULL,
        next_target_mileage INTEGER,
        cost                INTEGER DEFAULT 0,
        notes               TEXT,
        created_at          TEXT    NOT NULL,
        FOREIGN KEY (vehicle_uuid) REFERENCES vehicles (uuid) ON DELETE CASCADE
      )
    ''');

    // Performance indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_scans_vehicle ON obd_scans (vehicle_uuid, scan_date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_schedules_vehicle ON service_schedules (vehicle_uuid)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logs_vehicle ON service_logs (vehicle_uuid, service_date DESC)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    _log.i('DB onUpgrade: $oldVersion → $newVersion');
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_logs (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid                TEXT    NOT NULL UNIQUE,
          vehicle_uuid        TEXT    NOT NULL,
          service_date        TEXT    NOT NULL,
          service_type        TEXT    NOT NULL,
          oil_brand           TEXT,
          current_mileage     INTEGER NOT NULL,
          next_target_mileage INTEGER,
          cost                INTEGER DEFAULT 0,
          notes               TEXT,
          created_at          TEXT    NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add indexes for perf
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_scans_vehicle ON obd_scans (vehicle_uuid, scan_date DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_schedules_vehicle ON service_schedules (vehicle_uuid)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_logs_vehicle ON service_logs (vehicle_uuid, service_date DESC)');
    }
  }

  static Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('vehicles', {
      'uuid': 'default-honda-jazz-ge8',
      'name': 'My Jazz',
      'brand': 'Honda',
      'model': 'Jazz GE8',
      'year': 2008,
      'engine_type': '1.5L i-VTEC',
      'fuel_type': 'Petrol',
      'transmission_type': 'Manual',
      'current_mileage': 150000,
      'license_plate': 'B 1234 ABC',
      'color': 'Silver',
      'notes': 'Default vehicle',
      'created_at': now,
      'updated_at': now,
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    for (final s in _defaultSchedules('default-honda-jazz-ge8')) {
      await db.insert('service_schedules', s,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static List<Map<String, dynamic>> _defaultSchedules(String vehicleUuid) {
    final now = DateTime.now();
    return [
      {
        'uuid': '${vehicleUuid}_oil',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Ganti Oli Mesin',
        'description': 'Ganti oli mesin setiap 10.000 km atau 6 bulan.',
        'interval_mileage': 10000,
        'interval_months': 6,
        'last_service_mileage': 140000,
        'last_service_date':
            now.subtract(const Duration(days: 90)).toIso8601String(),
        'next_predicted_date':
            now.add(const Duration(days: 90)).toIso8601String(),
        'next_predicted_mileage': 150000,
        'is_enabled': 1,
      },
      {
        'uuid': '${vehicleUuid}_spark',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Busi',
        'description': 'Ganti busi setiap 40.000 km atau 24 bulan.',
        'interval_mileage': 40000,
        'interval_months': 24,
        'last_service_mileage': 120000,
        'last_service_date':
            now.subtract(const Duration(days: 360)).toIso8601String(),
        'next_predicted_date':
            now.add(const Duration(days: 360)).toIso8601String(),
        'next_predicted_mileage': 160000,
        'is_enabled': 1,
      },
      {
        'uuid': '${vehicleUuid}_brake_fluid',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Minyak Rem',
        'description': 'Ganti minyak rem setiap 40.000 km atau 24 bulan.',
        'interval_mileage': 40000,
        'interval_months': 24,
        'last_service_mileage': 130000,
        'last_service_date':
            now.subtract(const Duration(days: 180)).toIso8601String(),
        'next_predicted_date':
            now.add(const Duration(days: 540)).toIso8601String(),
        'next_predicted_mileage': 170000,
        'is_enabled': 1,
      },
      {
        'uuid': '${vehicleUuid}_coolant',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Air Radiator / Coolant',
        'description': 'Ganti coolant setiap 60.000 km atau 36 bulan.',
        'interval_mileage': 60000,
        'interval_months': 36,
        'last_service_mileage': 100000,
        'last_service_date':
            now.subtract(const Duration(days: 720)).toIso8601String(),
        'next_predicted_date':
            now.add(const Duration(days: 360)).toIso8601String(),
        'next_predicted_mileage': 160000,
        'is_enabled': 1,
      },
      {
        'uuid': '${vehicleUuid}_air_filter',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Filter Udara',
        'description': 'Ganti filter udara setiap 20.000 km atau 12 bulan.',
        'interval_mileage': 20000,
        'interval_months': 12,
        'last_service_mileage': 135000,
        'last_service_date':
            now.subtract(const Duration(days: 270)).toIso8601String(),
        'next_predicted_date':
            now.add(const Duration(days: 90)).toIso8601String(),
        'next_predicted_mileage': 155000,
        'is_enabled': 1,
      },
    ];
  }

  // ── OBD Scans ─────────────────────────────────────────────────────────────

  static Future<int> insertScan(Map<String, dynamic> scan) async {
    try {
      final db = await database;
      return await db.insert('obd_scans', scan,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      _log.e('DB insertScan', error: e, stackTrace: st);
      return -1;
    }
  }

  static Future<List<Map<String, dynamic>>> getScans(String vehicleUuid,
      {int limit = 100}) async {
    try {
      final db = await database;
      return await db.query(
        'obd_scans',
        where: 'vehicle_uuid = ?',
        whereArgs: [vehicleUuid],
        orderBy: 'scan_date DESC',
        limit: limit,
      );
    } catch (e, st) {
      _log.e('DB getScans', error: e, stackTrace: st);
      return [];
    }
  }

  static Future<int> deleteAllScans(String vehicleUuid) async {
    try {
      final db = await database;
      return await db.delete('obd_scans',
          where: 'vehicle_uuid = ?', whereArgs: [vehicleUuid]);
    } catch (e, st) {
      _log.e('DB deleteAllScans', error: e, stackTrace: st);
      return 0;
    }
  }

  static Future<int> deleteScan(String uuid) async {
    try {
      final db = await database;
      return await db.delete('obd_scans', where: 'uuid = ?', whereArgs: [uuid]);
    } catch (e, st) {
      _log.e('DB deleteScan', error: e, stackTrace: st);
      return 0;
    }
  }

  // ── Vehicles ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final db = await database;
      return await db.query('vehicles',
          where: 'is_active = 1', orderBy: 'created_at DESC');
    } catch (e, st) {
      _log.e('DB getVehicles', error: e, stackTrace: st);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getVehicle(String uuid) async {
    try {
      final db = await database;
      final rows = await db.query('vehicles',
          where: 'uuid = ?', whereArgs: [uuid], limit: 1);
      return rows.isEmpty ? null : rows.first;
    } catch (e, st) {
      _log.e('DB getVehicle', error: e, stackTrace: st);
      return null;
    }
  }

  static Future<int> insertVehicle(Map<String, dynamic> vehicle) async {
    try {
      final db = await database;
      return await db.insert('vehicles', vehicle,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      _log.e('DB insertVehicle', error: e, stackTrace: st);
      return -1;
    }
  }

  static Future<int> updateVehicle(Map<String, dynamic> vehicle) async {
    try {
      final db = await database;
      final updated = Map<String, dynamic>.from(vehicle)
        ..['updated_at'] = DateTime.now().toIso8601String();
      return await db.update('vehicles', updated,
          where: 'uuid = ?', whereArgs: [vehicle['uuid']]);
    } catch (e, st) {
      _log.e('DB updateVehicle', error: e, stackTrace: st);
      return 0;
    }
  }

  static Future<int> deleteVehicle(String uuid) async {
    try {
      final db = await database;
      return await db.delete('vehicles',
          where: 'uuid = ?', whereArgs: [uuid]);
    } catch (e, st) {
      _log.e('DB deleteVehicle', error: e, stackTrace: st);
      return 0;
    }
  }

  static Future<int> updateVehicleMileage(
      String vehicleUuid, int mileage) async {
    try {
      final db = await database;
      return await db.update(
        'vehicles',
        {
          'current_mileage': mileage,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'uuid = ?',
        whereArgs: [vehicleUuid],
      );
    } catch (e, st) {
      _log.e('DB updateVehicleMileage', error: e, stackTrace: st);
      return 0;
    }
  }

  // ── Service Schedules ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSchedules(
      String vehicleUuid) async {
    try {
      final db = await database;
      return await db.query(
        'service_schedules',
        where: 'vehicle_uuid = ? AND is_enabled = 1',
        whereArgs: [vehicleUuid],
        orderBy: 'next_predicted_date ASC',
      );
    } catch (e, st) {
      _log.e('DB getSchedules', error: e, stackTrace: st);
      return [];
    }
  }

  static Future<int> insertOrUpdateSchedule(
      Map<String, dynamic> schedule) async {
    try {
      final db = await database;
      return await db.insert('service_schedules', schedule,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      _log.e('DB insertOrUpdateSchedule', error: e, stackTrace: st);
      return -1;
    }
  }

  static Future<int> deleteSchedule(String uuid) async {
    try {
      final db = await database;
      return await db
          .delete('service_schedules', where: 'uuid = ?', whereArgs: [uuid]);
    } catch (e, st) {
      _log.e('DB deleteSchedule', error: e, stackTrace: st);
      return 0;
    }
  }

  // ── Service Logs ──────────────────────────────────────────────────────────

  static Future<int> insertServiceLog(Map<String, dynamic> log) async {
    try {
      final db = await database;
      return await db.insert('service_logs', log,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      _log.e('DB insertServiceLog', error: e, stackTrace: st);
      return -1;
    }
  }

  static Future<List<Map<String, dynamic>>> getServiceLogs(
      String vehicleUuid) async {
    try {
      final db = await database;
      return await db.query(
        'service_logs',
        where: 'vehicle_uuid = ?',
        whereArgs: [vehicleUuid],
        orderBy: 'service_date DESC',
      );
    } catch (e, st) {
      _log.e('DB getServiceLogs', error: e, stackTrace: st);
      return [];
    }
  }

  static Future<int> updateServiceLog(Map<String, dynamic> log) async {
    try {
      final db = await database;
      return await db.update('service_logs', log,
          where: 'uuid = ?', whereArgs: [log['uuid']]);
    } catch (e, st) {
      _log.e('DB updateServiceLog', error: e, stackTrace: st);
      return 0;
    }
  }

  static Future<int> deleteServiceLog(String uuid) async {
    try {
      final db = await database;
      return await db.delete('service_logs',
          where: 'uuid = ?', whereArgs: [uuid]);
    } catch (e, st) {
      _log.e('DB deleteServiceLog', error: e, stackTrace: st);
      return 0;
    }
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'smart_obd.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            brand TEXT NOT NULL,
            model TEXT NOT NULL,
            year INTEGER NOT NULL,
            engine_type TEXT NOT NULL,
            fuel_type TEXT NOT NULL,
            transmission_type TEXT NOT NULL,
            vin TEXT,
            current_mileage INTEGER DEFAULT 0,
            license_plate TEXT,
            color TEXT,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_active INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE service_schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            vehicle_uuid TEXT NOT NULL,
            service_name TEXT NOT NULL,
            description TEXT,
            interval_mileage INTEGER NOT NULL,
            interval_months INTEGER NOT NULL,
            last_service_mileage INTEGER DEFAULT 0,
            last_service_date TEXT,
            next_predicted_date TEXT,
            next_predicted_mileage INTEGER,
            is_enabled INTEGER DEFAULT 1,
            FOREIGN KEY (vehicle_uuid) REFERENCES vehicles (uuid)
          )
        ''');

        await db.execute('''
          CREATE TABLE obd_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            vehicle_uuid TEXT NOT NULL,
            scan_date TEXT NOT NULL,
            coolant_temp REAL,
            battery_voltage REAL,
            rpm REAL,
            speed REAL,
            fuel_trim REAL,
            dtc_codes TEXT,
            notes TEXT,
            mileage INTEGER DEFAULT 0,
            FOREIGN KEY (vehicle_uuid) REFERENCES vehicles (uuid)
          )
        ''');

        // Seed default vehicle
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
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_active': 1,
        });

        // Seed schedules
        for (final s in _defaultSchedules('default-honda-jazz-ge8')) {
          await db.insert('service_schedules', s);
        }
      },
    );
  }

  static List<Map<String, dynamic>> _defaultSchedules(String vehicleUuid) {
    final now = DateTime.now();
    return [
      {
        'uuid': '${vehicleUuid}_oil',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Oil Change',
        'interval_mileage': 10000,
        'interval_months': 6,
        'last_service_mileage': 140000,
        'last_service_date': now.subtract(const Duration(days: 90)).toIso8601String(),
        'next_predicted_date': now.add(const Duration(days: 90)).toIso8601String(),
        'next_predicted_mileage': 150000,
      },
      {
        'uuid': '${vehicleUuid}_spark',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Spark Plugs',
        'interval_mileage': 40000,
        'interval_months': 24,
        'last_service_mileage': 120000,
        'last_service_date': now.subtract(const Duration(days: 360)).toIso8601String(),
        'next_predicted_date': now.add(const Duration(days: 360)).toIso8601String(),
        'next_predicted_mileage': 160000,
      },
      {
        'uuid': '${vehicleUuid}_brake_fluid',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Brake Fluid',
        'interval_mileage': 40000,
        'interval_months': 24,
        'last_service_mileage': 130000,
        'last_service_date': now.subtract(const Duration(days: 180)).toIso8601String(),
        'next_predicted_date': now.add(const Duration(days: 540)).toIso8601String(),
        'next_predicted_mileage': 170000,
      },
      {
        'uuid': '${vehicleUuid}_coolant',
        'vehicle_uuid': vehicleUuid,
        'service_name': 'Coolant',
        'interval_mileage': 60000,
        'interval_months': 36,
        'last_service_mileage': 100000,
        'last_service_date': now.subtract(const Duration(days: 720)).toIso8601String(),
        'next_predicted_date': now.add(const Duration(days: 360)).toIso8601String(),
        'next_predicted_mileage': 160000,
      },
    ];
  }

  // --- CRUD Methods ---
  static Future<int> insertScan(Map<String, dynamic> scan) async {
    final db = await database;
    return await db.insert('obd_scans', scan, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getScans(String vehicleUuid) async {
    final db = await database;
    return await db.query('obd_scans', where: 'vehicle_uuid = ?', whereArgs: [vehicleUuid], orderBy: 'scan_date DESC');
  }

  static Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await database;
    return await db.query('vehicles', orderBy: 'created_at DESC');
  }

  static Future<int> insertVehicle(Map<String, dynamic> vehicle) async {
    final db = await database;
    return await db.insert('vehicles', vehicle, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> deleteVehicle(String uuid) async {
    final db = await database;
    // Also delete associated schedules and scans (cascade simulates manually just in case)
    await db.delete('service_schedules', where: 'vehicle_uuid = ?', whereArgs: [uuid]);
    await db.delete('obd_scans', where: 'vehicle_uuid = ?', whereArgs: [uuid]);
    return await db.delete('vehicles', where: 'uuid = ?', whereArgs: [uuid]);
  }

  static Future<int> updateVehicleMileage(String vehicleUuid, int mileage) async {
    final db = await database;
    return await db.update('vehicles', {'current_mileage': mileage, 'updated_at': DateTime.now().toIso8601String()}, where: 'uuid = ?', whereArgs: [vehicleUuid]);
  }

  static Future<List<Map<String, dynamic>>> getSchedules(String vehicleUuid) async {
    final db = await database;
    return await db.query('service_schedules', where: 'vehicle_uuid = ?', whereArgs: [vehicleUuid]);
  }

  static Future<int> insertOrUpdateSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.insert('service_schedules', schedule, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
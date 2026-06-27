import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get make => text().withLength(min: 1, max: 50)();
  TextColumn get model => text().withLength(min: 1, max: 50)();
  IntColumn get year => integer()();
  TextColumn get transmission => text().withLength(min: 1, max: 20)();
  TextColumn get vin => text().nullable().withLength(min: 17, max: 17)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class MaintenanceThresholds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  TextColumn get componentName => text()(); // e.g. "Oli Mesin", "Busi"
  IntColumn get intervalKm => integer()();
  IntColumn get intervalMonths => integer()();
}

class OBDScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  RealColumn get coolantTemp => real()();
  RealColumn get batteryVoltage => real()();
  RealColumn get fuelTrim => real()();
  RealColumn get rpm => real()();
  TextColumn get dtcCodes => text()(); // Comma-separated or JSON
}

@DriftDatabase(tables: [Vehicles, MaintenanceThresholds, OBDScans])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // Upgraded version for global vehicles

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Upgrade logic if needed
      }
    );
  }

  // Future feature: add vehicle and thresholds dynamically
  Future<int> addVehicleWithThresholds(
    VehiclesCompanion vehicle, 
    List<MaintenanceThresholdsCompanion> thresholds
  ) async {
    return await transaction(() async {
      final vehicleId = await into(vehicles).insert(vehicle);
      
      final thresholdsWithId = thresholds.map((t) => 
        t.copyWith(vehicleId: Value(vehicleId))
      ).toList();
      
      await batch((batch) {
        batch.insertAll(maintenanceThresholds, thresholdsWithId);
      });
      
      return vehicleId;
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'smart_obd.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

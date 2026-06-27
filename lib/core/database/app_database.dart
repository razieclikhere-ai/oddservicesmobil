import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get brand => text()();
  TextColumn get model => text()();
  IntColumn get year => integer()();
  TextColumn get engineType => text()();
  TextColumn get fuelType => text()();
  TextColumn get transmissionType => text()();
  TextColumn get vin => text().nullable()();
  IntColumn get currentMileage => integer().withDefault(const Constant(0))();
  TextColumn get licensePlate => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ObdScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get vehicleId => integer().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scanDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get mileageAtScan => integer()();
  TextColumn get scanType => text().withDefault(const Constant('full'))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TroubleCodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get scanId => integer().references(ObdScans, #id, onDelete: KeyAction.cascade)();
  TextColumn get code => text()();
  TextColumn get description => text()();
  TextColumn get severity => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get freezeFrameData => text().nullable()();
  DateTimeColumn get firstDetected => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastDetected => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get clearedAt => dateTime().nullable()();
}

class LiveDataReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get scanId => integer().references(ObdScans, #id, onDelete: KeyAction.cascade)();
  TextColumn get pid => text()();
  TextColumn get pidName => text()();
  TextColumn get value => text()();
  TextColumn get unit => text()();
  TextColumn get category => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class FreezeFrames extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get troubleCodeId => integer().references(TroubleCodes, #id, onDelete: KeyAction.cascade)();
  TextColumn get pid => text()();
  TextColumn get pidName => text()();
  TextColumn get value => text()();
  TextColumn get unit => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class ServiceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get vehicleId => integer().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get serviceDate => dateTime()();
  IntColumn get mileage => integer()();
  TextColumn get serviceType => text()();
  TextColumn get description => text()();
  RealColumn get cost => real().nullable()();
  TextColumn get provider => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get nextServiceType => text().nullable()();
  IntColumn get nextServiceMileage => integer().nullable()();
  DateTimeColumn get nextServiceDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ServiceSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get vehicleId => integer().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceName => text()();
  TextColumn get description => text().nullable()();
  IntColumn get intervalMileage => integer()();
  IntColumn get intervalMonths => integer()();
  IntColumn get lastServiceMileage => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastServiceDate => dateTime().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get notifyBeforeMileage => integer().withDefault(const Constant(1000))();
  IntColumn get notifyBeforeDays => integer().withDefault(const Constant(30))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class VehicleProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get vehicleId => integer().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get profileName => text()();
  TextColumn get obdProtocol => text().withDefault(const Constant('auto'))();
  TextColumn get obdAdapterType => text().withDefault(const Constant('bluetooth'))();
  TextColumn get adapterAddress => text().nullable()();
  TextColumn get customPids => text().nullable()();
  TextColumn get settings => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class AiAnalysisResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get scanId => integer().references(ObdScans, #id, onDelete: KeyAction.cascade)();
  TextColumn get analysisType => text()();
  TextColumn get summary => text()();
  TextColumn get detailedFindings => text()();
  TextColumn get recommendations => text()();
  TextColumn get riskLevel => text()();
  RealColumn get confidenceScore => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ScanTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get pidList => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Vehicles,
  ObdScans,
  TroubleCodes,
  LiveDataReadings,
  FreezeFrames,
  ServiceRecords,
  ServiceSchedules,
  VehicleProfiles,
  AiAnalysisResults,
  UserPreferences,
  ScanTemplates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _insertDefaultData();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Handle migrations here
        },
      );

  Future<void> _insertDefaultData() async {
    final uuid = const Uuid();
    final vehicleId = uuid.v4();
    final now = DateTime.now();

    await batch((batch) {
      // Insert default vehicle (Honda Jazz GE8 2008 Manual)
      batch.insert(vehicles, VehiclesCompanion.insert(
        uuid: vehicleId,
        name: 'My Jazz',
        brand: 'Honda',
        model: 'Jazz GE8',
        year: 2008,
        engineType: '1.5L L15A i-VTEC',
        fuelType: 'Petrol',
        transmissionType: 'Manual 5-Speed',
        vin: 'JHZGE8-SAMPLE-VIN',
        currentMileage: 150000,
        licensePlate: 'B 1234 ABC',
        color: 'Silver',
        notes: 'Default vehicle profile - Oil change every 10,000 km / 6 months',
        createdAt: now,
        updatedAt: now,
        isActive: const Constant(true),
      ));

      // Insert default service schedules for the vehicle
      batch.insert(serviceSchedules, ServiceSchedulesCompanion.insert(
        uuid: uuid.v4(),
        vehicleId: vehicleId,
        serviceName: 'Oil Change',
        description: 'Engine oil and filter replacement',
        intervalMileage: 10000,
        intervalMonths: 6,
        lastServiceMileage: 140000,
        lastServiceDate: now.subtract(const Duration(days: 90)),
        notifyBeforeMileage: 1000,
        notifyBeforeDays: 30,
      ));
      batch.insert(serviceSchedules, ServiceSchedulesCompanion.insert(
        uuid: uuid.v4(),
        vehicleId: vehicleId,
        serviceName: 'Spark Plugs',
        description: 'Replace spark plugs',
        intervalMileage: 40000,
        intervalMonths: 24,
        lastServiceMileage: 120000,
        lastServiceDate: now.subtract(const Duration(days: 365)),
        notifyBeforeMileage: 2000,
        notifyBeforeDays: 60,
      ));
      batch.insert(serviceSchedules, ServiceSchedulesCompanion.insert(
        uuid: uuid.v4(),
        vehicleId: vehicleId,
        serviceName: 'Brake Fluid',
        description: 'Replace brake fluid',
        intervalMileage: 40000,
        intervalMonths: 24,
        lastServiceMileage: 130000,
        lastServiceDate: now.subtract(const Duration(days: 180)),
        notifyBeforeMileage: 2000,
        notifyBeforeDays: 60,
      ));
      batch.insert(serviceSchedules, ServiceSchedulesCompanion.insert(
        uuid: uuid.v4(),
        vehicleId: vehicleId,
        serviceName: 'Coolant',
        description: 'Replace engine coolant',
        intervalMileage: 60000,
        intervalMonths: 36,
        lastServiceMileage: 100000,
        lastServiceDate: now.subtract(const Duration(days: 730)),
        notifyBeforeMileage: 5000,
        notifyBeforeDays: 90,
      ));
      batch.insert(serviceSchedules, ServiceSchedulesCompanion.insert(
        uuid: uuid.v4(),
        vehicleId: vehicleId,
        serviceName: 'Transmission Oil',
        description: 'Manual transmission fluid change',
        intervalMileage: 80000,
        intervalMonths: 48,
        lastServiceMileage: 80000,
        lastServiceDate: now.subtract(const Duration(days: 1095)),
        notifyBeforeMileage: 5000,
        notifyBeforeDays: 90,
      ));

      // Insert scan templates
      batch.insert(scanTemplates, ScanTemplatesCompanion.insert(
        uuid: uuid.v4(),
        name: 'Full Scan',
        description: 'Complete OBD-II diagnostic scan',
        pidList: '["0100","0101","0102","0103","0104","0105","0106","0107","010C","010D","010E","010F","0110","0111","0113","0114","0115","011F","012F","0130","0131","0132","0133","0134","0135","0136","0137","0138","0139","013A","013B","013C","013D","013E","013F","0140","0141","0142","0143","0144","0145","0146","0147","0148","0149","014A","014B","014C","014D","014E","014F","0150","0151","0152","0153","0154","0155","0156","0157","0158","0159","015A","015B","015C","015D","015E","015F"]',
        isBuiltIn: const Constant(true),
      ));
      batch.insert(scanTemplates, ScanTemplatesCompanion.insert(
        uuid: uuid.v4(),
        name: 'Quick Check',
        description: 'Essential parameters only',
        pidList: '["0100","0101","0102","0103","0104","0105","010C","010D","010E","010F","0111"]',
        isBuiltIn: const Constant(true),
      ));
      batch.insert(scanTemplates, ScanTemplatesCompanion.insert(
        uuid: uuid.v4(),
        name: 'Emission Test',
        description: 'Emission-related parameters',
        pidList: '["0100","0101","0102","0103","0104","0105","010C","010D","010E","010F","0111","012F","0130","0131","0132","0133","0134","0135","0136","0137","0138","0139","013A","013B","013C","013D","013E","013F"]',
        isBuiltIn: const Constant(true),
      ));
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'smart_obd.db'));
    return NativeDatabase.createInBackground(file);
  });
}
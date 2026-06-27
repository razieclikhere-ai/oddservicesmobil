import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Vehicles extends Table with AutoIncrementingPrimaryKeys {
  TextColumn get uuid => text()
      .clientDefault(() => const Uuid().v4())
      .unique()();
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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
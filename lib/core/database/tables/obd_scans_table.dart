import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class ObdScans extends Table with AutoIncrementingPrimaryKeys {
  TextColumn get uuid => text()
      .clientDefault(() => const Uuid().v4())
      .unique()();
  IntColumn get vehicleId => integer()
      .references(Vehicles, #id)
      .withConstraints(const ReferenceAction.cascade)();
  DateTimeColumn get scanDate => dateTime().clientDefault(DateTime.now)();
  IntColumn get mileageAtScan => integer()();
  TextColumn get scanType =>
      text().clientDefault(const Constant('full'))();
  TextColumn get status =>
      text().clientDefault(const Constant('completed'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
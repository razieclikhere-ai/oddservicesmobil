import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class TroubleCodes extends Table with AutoIncrementingPrimaryKeys {
  TextColumn get uuid => text()
      .clientDefault(() => const Uuid().v4())
      .unique()();
  IntColumn get scanId => integer()
      .references(ObdScans, #id)
      .withConstraints(const ReferenceAction.cascade)();
  TextColumn get code => text()();
  TextColumn get description => text()();
  TextColumn get severity =>
      text().clientDefault(const Constant('medium'))();
  TextColumn get status =>
      text().clientDefault(const Constant('active'))();
  TextColumn get freezeFrameData => text().nullable()();
  DateTimeColumn get firstDetected =>
      dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get lastDetected =>
      dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get clearedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
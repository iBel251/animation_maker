import 'package:drift/drift.dart';

class CanvasProjects extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  RealColumn get fps => real()();
  TextColumn get backgroundKind => text()();
  IntColumn get backgroundColor => integer().nullable()();
  TextColumn get backgroundImagePath => text().nullable()();
  TextColumn get documentJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

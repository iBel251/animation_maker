import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'daos/app_metadata_dao.dart';
import 'daos/canvas_project_dao.dart';
import 'tables/app_metadata_table.dart';
import 'tables/canvas_projects_table.dart';

part 'canvas_database.g.dart';

@DriftDatabase(
  tables: [CanvasProjects, AppMetadata],
  daos: [CanvasProjectDao, AppMetadataDao],
)
class CanvasDatabase extends _$CanvasDatabase {
  CanvasDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_canvas_projects_updated_at ON canvas_projects(updated_at)',
          );
          await customStatement(
            'CREATE INDEX idx_canvas_projects_title ON canvas_projects(title)',
          );
        },
        onUpgrade: (m, from, to) async {
          // Future migrations live here.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'animation_maker.db'));
    return NativeDatabase.createInBackground(file);
  });
}

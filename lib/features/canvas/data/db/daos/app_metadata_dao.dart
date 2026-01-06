import 'package:drift/drift.dart';

import '../canvas_database.dart';
import '../tables/app_metadata_table.dart';

part 'app_metadata_dao.g.dart';

@DriftAccessor(tables: [AppMetadata])
class AppMetadataDao extends DatabaseAccessor<CanvasDatabase>
    with _$AppMetadataDaoMixin {
  AppMetadataDao(CanvasDatabase db) : super(db);

  Future<String?> getValue(String key) async {
    final row = await (select(appMetadata)..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(appMetadata).insert(
      AppMetadataCompanion(
        key: Value(key),
        value: Value(value),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }
}

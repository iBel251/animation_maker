import 'package:drift/drift.dart';

import '../canvas_database.dart';
import '../tables/canvas_projects_table.dart';

part 'canvas_project_dao.g.dart';

@DriftAccessor(tables: [CanvasProjects])
class CanvasProjectDao extends DatabaseAccessor<CanvasDatabase>
    with _$CanvasProjectDaoMixin {
  CanvasProjectDao(CanvasDatabase db) : super(db);

  Future<CanvasProject?> fetchProject(String id) {
    return (select(canvasProjects)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<CanvasProject>> fetchAllProjects() {
    return (select(canvasProjects)
          ..orderBy(
            [
              (tbl) => OrderingTerm(
                    expression: tbl.updatedAt,
                    mode: OrderingMode.desc,
                  ),
            ],
          ))
        .get();
  }

  Future<List<CanvasProjectSummaryRow>> fetchSummaries() async {
    final query = selectOnly(canvasProjects)
      ..addColumns([
        canvasProjects.id,
        canvasProjects.title,
        canvasProjects.updatedAt,
      ])
      ..orderBy([
        OrderingTerm(
          expression: canvasProjects.updatedAt,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => CanvasProjectSummaryRow(
            id: row.read(canvasProjects.id)!,
            title: row.read(canvasProjects.title)!,
            updatedAt: row.read(canvasProjects.updatedAt)!,
          ),
        )
        .toList(growable: false);
  }

  Future<bool> hasProjects() async {
    final countExp = canvasProjects.id.count();
    final query = selectOnly(canvasProjects)..addColumns([countExp]);
    final row = await query.getSingle();
    final count = row.read(countExp) ?? 0;
    return count > 0;
  }

  Future<void> upsertProject(CanvasProjectsCompanion entry) {
    return into(canvasProjects).insert(
      entry,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> upsertProjects(List<CanvasProjectsCompanion> entries) async {
    if (entries.isEmpty) return;
    await batch(
      (batch) => batch.insertAllOnConflictUpdate(
        canvasProjects,
        entries,
      ),
    );
  }

  Future<int> deleteProject(String id) {
    return (delete(canvasProjects)..where((tbl) => tbl.id.equals(id))).go();
  }
}

class CanvasProjectSummaryRow {
  const CanvasProjectSummaryRow({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int updatedAt;
}

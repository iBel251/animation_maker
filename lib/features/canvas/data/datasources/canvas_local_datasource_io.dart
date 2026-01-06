import 'package:animation_maker/features/canvas/data/db/canvas_database.dart';
import 'package:animation_maker/features/canvas/data/db/daos/app_metadata_dao.dart';
import 'package:animation_maker/features/canvas/data/db/daos/canvas_project_dao.dart';
import 'package:animation_maker/features/canvas/data/db/mappers/canvas_project_mapper.dart';
import 'package:animation_maker/features/canvas/data/db/migrations/legacy_document_importer.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';

class CanvasLocalDataSource {
  CanvasLocalDataSource._(
    this._projectDao,
    this._mapper,
    this._importer,
  );

  factory CanvasLocalDataSource({CanvasDatabase? database}) {
    final db = database ?? CanvasDatabase();
    final projectDao = CanvasProjectDao(db);
    final metadataDao = AppMetadataDao(db);
    final mapper = const CanvasProjectMapper();
    final importer = LegacyDocumentImporter(
      projectDao: projectDao,
      metadataDao: metadataDao,
      mapper: mapper,
    );
    return CanvasLocalDataSource._(projectDao, mapper, importer);
  }

  final CanvasProjectDao _projectDao;
  final CanvasProjectMapper _mapper;
  final LegacyDocumentImporter _importer;
  Future<void>? _legacyImport;

  Future<void> saveDocument(CanvasDocument document) async {
    await _ensureImported();
    final entry = _mapper.toCompanion(document);
    await _projectDao.upsertProject(entry);
  }

  Future<CanvasDocument?> loadDocument(String id) async {
    await _ensureImported();
    final row = await _projectDao.fetchProject(id);
    if (row == null) return null;
    return _mapper.toDocument(row);
  }

  Future<void> deleteDocument(String id) async {
    await _ensureImported();
    await _projectDao.deleteProject(id);
  }

  Future<List<CanvasDocumentSummary>> listDocuments() async {
    await _ensureImported();
    final rows = await _projectDao.fetchSummaries();
    return rows.map(_mapper.toSummary).toList(growable: false);
  }

  Future<void> _ensureImported() {
    return _legacyImport ??= _importer.importIfNeeded();
  }
}

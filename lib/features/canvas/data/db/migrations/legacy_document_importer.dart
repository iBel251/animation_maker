import 'dart:io';

import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:path_provider/path_provider.dart';

import '../canvas_database.dart';
import '../daos/app_metadata_dao.dart';
import '../daos/canvas_project_dao.dart';
import '../mappers/canvas_project_mapper.dart';

class LegacyDocumentImporter {
  LegacyDocumentImporter({
    required CanvasProjectDao projectDao,
    required AppMetadataDao metadataDao,
    Directory? legacyRoot,
    CanvasProjectMapper? mapper,
  })  : _projectDao = projectDao,
        _metadataDao = metadataDao,
        _legacyRootOverride = legacyRoot,
        _mapper = mapper ?? const CanvasProjectMapper();

  static const String _importFlagKey = 'legacy_import_complete';

  final CanvasProjectDao _projectDao;
  final AppMetadataDao _metadataDao;
  final Directory? _legacyRootOverride;
  final CanvasProjectMapper _mapper;

  Future<void> importIfNeeded() async {
    if (await _isImportComplete()) return;
    if (await _projectDao.hasProjects()) {
      await _markImportComplete();
      return;
    }
    final files = await _listLegacyFiles();
    if (files.isEmpty) {
      await _markImportComplete();
      return;
    }

    final entries = await _decodeDocuments(files);
    await _projectDao.upsertProjects(entries);
    await _markImportComplete();
  }

  Future<bool> _isImportComplete() async {
    final value = await _metadataDao.getValue(_importFlagKey);
    return value == 'true';
  }

  Future<void> _markImportComplete() {
    return _metadataDao.setValue(_importFlagKey, 'true');
  }

  Future<List<File>> _listLegacyFiles() async {
    final root = await _resolveLegacyRoot();
    if (!await root.exists()) return const [];
    final files = <File>[];
    await for (final entity in root.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<Directory> _resolveLegacyRoot() async {
    if (_legacyRootOverride != null) return _legacyRootOverride!;
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}canvas_documents');
  }

  Future<List<CanvasProjectsCompanion>> _decodeDocuments(
    List<File> files,
  ) async {
    final entries = <CanvasProjectsCompanion>[];
    for (final file in files) {
      final document = await _readDocument(file);
      if (document == null) continue;
      entries.add(_mapper.toCompanion(document));
    }
    return entries;
  }

  Future<CanvasDocument?> _readDocument(File file) async {
    try {
      final raw = await file.readAsString();
      return CanvasDocumentCodec.decode(raw);
    } catch (_) {
      return null;
    }
  }
}

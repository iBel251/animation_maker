import 'package:animation_maker/features/canvas/data/datasources/canvas_local_datasource.dart';
import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';

class CanvasRepositoryImpl implements CanvasRepository {
  CanvasRepositoryImpl({CanvasLocalDataSource? localDataSource})
      : _local = localDataSource ?? CanvasLocalDataSource();

  final CanvasLocalDataSource _local;

  @override
  Future<CanvasDocument?> loadDocument(String id) {
    return _local.loadDocument(id);
  }

  @override
  Future<void> saveDocument(CanvasDocument document) {
    return _local.saveDocument(document);
  }

  @override
  Future<void> deleteDocument(String id) {
    return _local.deleteDocument(id);
  }

  @override
  Future<List<CanvasDocumentSummary>> listDocuments() {
    return _local.listDocuments();
  }

  @override
  Future<String> exportDocument(CanvasDocument document) async {
    return CanvasDocumentCodec.encode(document);
  }

  @override
  Future<CanvasDocument> importDocument(String raw) async {
    return CanvasDocumentCodec.decode(raw);
  }
}

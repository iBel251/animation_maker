import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';

abstract class CanvasRepository {
  Future<CanvasDocument?> loadDocument(String id);
  Future<void> saveDocument(CanvasDocument document);
  Future<void> deleteDocument(String id);
  Future<List<CanvasDocumentSummary>> listDocuments();

  Future<String> exportDocument(CanvasDocument document);
  Future<CanvasDocument> importDocument(String raw);
}


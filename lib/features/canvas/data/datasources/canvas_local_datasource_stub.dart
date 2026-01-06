import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';

class CanvasLocalDataSource {
  CanvasLocalDataSource({Object? database});

  Future<void> saveDocument(CanvasDocument document) async {
    throw UnsupportedError('Local storage is not available on this platform.');
  }

  Future<CanvasDocument?> loadDocument(String id) async {
    throw UnsupportedError('Local storage is not available on this platform.');
  }

  Future<void> deleteDocument(String id) async {
    throw UnsupportedError('Local storage is not available on this platform.');
  }

  Future<List<CanvasDocumentSummary>> listDocuments() async {
    throw UnsupportedError('Local storage is not available on this platform.');
  }
}

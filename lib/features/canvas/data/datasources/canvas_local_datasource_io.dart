import 'dart:convert';
import 'dart:io';

import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:path/path.dart' as p;

class CanvasLocalDataSource {
  CanvasLocalDataSource({Directory? root})
      : _root = root ?? Directory('canvas_documents');

  final Directory _root;

  Future<void> saveDocument(CanvasDocument document) async {
    await _ensureRoot();
    final file = _documentFile(document.id);
    final raw = CanvasDocumentCodec.encode(document);
    await file.writeAsString(raw);
  }

  Future<CanvasDocument?> loadDocument(String id) async {
    final file = _documentFile(id);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return CanvasDocumentCodec.decode(raw);
  }

  Future<void> deleteDocument(String id) async {
    final file = _documentFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<CanvasDocumentSummary>> listDocuments() async {
    if (!await _root.exists()) return const [];
    final files = _root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    final summaries = <CanvasDocumentSummary>[];
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final id = (decoded['id'] as String?) ??
              p.basenameWithoutExtension(file.path);
          final title = (decoded['title'] as String?) ?? 'Untitled';
          final updatedRaw = decoded['updatedAt'];
          final updated = updatedRaw is String
              ? DateTime.tryParse(updatedRaw)
              : null;
          summaries.add(
            CanvasDocumentSummary(
              id: id,
              title: title,
              updatedAt: updated ?? DateTime.now(),
            ),
          );
        }
      } catch (_) {
        // Skip unreadable files.
      }
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<void> _ensureRoot() async {
    if (!await _root.exists()) {
      await _root.create(recursive: true);
    }
  }

  File _documentFile(String id) {
    return File(p.join(_root.path, '$id.json'));
  }
}

import 'dart:ui';

import 'package:drift/drift.dart';

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';

import '../canvas_database.dart';
import '../daos/canvas_project_dao.dart';

class CanvasProjectMapper {
  const CanvasProjectMapper();

  CanvasProjectsCompanion toCompanion(CanvasDocument document) {
    final background = document.background;
    return CanvasProjectsCompanion(
      id: Value(document.id),
      title: Value(document.title),
      width: Value(document.size.width),
      height: Value(document.size.height),
      fps: Value(document.fps),
      backgroundKind: Value(background.kind.name),
      backgroundColor: Value(background.color?.value),
      backgroundImagePath: Value(background.imagePath),
      documentJson: Value(CanvasDocumentCodec.encode(document)),
      createdAt: Value(document.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(document.updatedAt.millisecondsSinceEpoch),
      version: Value(document.version),
    );
  }

  CanvasDocument toDocument(CanvasProject row) {
    try {
      return CanvasDocumentCodec.decode(row.documentJson);
    } catch (_) {
      return _fallbackDocument(row);
    }
  }

  CanvasDocumentSummary toSummary(CanvasProjectSummaryRow row) {
    return CanvasDocumentSummary(
      id: row.id,
      title: row.title,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  CanvasDocument _fallbackDocument(CanvasProject row) {
    return CanvasDocument.singleLayer(
      id: row.id,
      title: row.title,
      size: Size(row.width, row.height),
      background: _backgroundFromRow(row),
      fps: row.fps,
      frameCount: kDefaultFrameCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      version: row.version,
    );
  }

  CanvasBackground _backgroundFromRow(CanvasProject row) {
    final kind = _parseBackgroundKind(row.backgroundKind);
    final color = row.backgroundColor != null
        ? Color(row.backgroundColor!)
        : kDefaultCanvasBackgroundColor;
    switch (kind) {
      case CanvasBackgroundKind.transparent:
        return const CanvasBackground.transparent();
      case CanvasBackgroundKind.image:
        final path = row.backgroundImagePath;
        if (path != null && path.isNotEmpty) {
          return CanvasBackground.image(path, fallbackColor: color);
        }
        return CanvasBackground.solid(color);
      case CanvasBackgroundKind.solid:
        return CanvasBackground.solid(color);
    }
  }

  CanvasBackgroundKind _parseBackgroundKind(String value) {
    for (final kind in CanvasBackgroundKind.values) {
      if (kind.name == value) return kind;
    }
    return CanvasBackgroundKind.solid;
  }
}

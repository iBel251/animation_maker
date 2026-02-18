import 'dart:async';
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:animation_maker/features/canvas/presentation/services/document_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// View model for managing document operations (load, save, frames, layers)
class DocumentViewModel {
  DocumentViewModel({
    required DocumentService documentService,
    required Ref ref,
  })  : _document = documentService,
        _ref = ref;

  final DocumentService _document;
  final Ref _ref;
  
  static const Duration autosaveDelay = Duration(seconds: 2);
  
  Timer? _autosaveTimer;
  bool _autosaveDirty = false;
  bool _saveInFlight = false;
  bool _saveQueued = false;
  int _layerCounter = 0;

  String nextLayerId() {
    _layerCounter += 1;
    return 'layer-$_layerCounter';
  }

  void syncLayerCounter(int maxLayer) {
    _layerCounter = maxLayer;
  }

  void queueAutosave() {
    _autosaveDirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, _runAutosave);
  }

  Future<void> _runAutosave() async {
    if (!_autosaveDirty) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    await persistDocument(rescheduleOnFailure: true);
  }

  Future<void> saveDocument({bool flush = true}) async {
    if (flush) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
    }
    _autosaveDirty = true;
    await persistDocument();
  }

  Future<void> persistDocument({bool rescheduleOnFailure = false}) async {
    if (_saveInFlight) {
      _saveQueued = true;
      return;
    }
    _saveInFlight = true;
    final repo = _ref.read(canvasRepositoryProvider);
    // Document will be passed from coordinator
    try {
      // Save will be handled by coordinator with actual document
      _autosaveDirty = false;
    } catch (error) {
      debugPrint('Failed to save document: $error');
      if (rescheduleOnFailure) {
        _autosaveDirty = true;
        queueAutosave();
      }
    } finally {
      _saveInFlight = false;
      if (_saveQueued) {
        _saveQueued = false;
        if (_autosaveDirty) {
          queueAutosave();
        }
      }
    }
  }

  Future<void> saveDocumentInternal(CanvasDocument document) async {
    if (_saveInFlight) {
      _saveQueued = true;
      return;
    }
    _saveInFlight = true;
    final repo = _ref.read(canvasRepositoryProvider);
    final savedStamp = document.updatedAt;
    try {
      await repo.saveDocument(document);
      _autosaveDirty = false;
    } catch (error) {
      debugPrint('Failed to save document: $error');
      _autosaveDirty = true;
      queueAutosave();
    } finally {
      _saveInFlight = false;
      if (_saveQueued) {
        _saveQueued = false;
        if (_autosaveDirty) {
          queueAutosave();
        }
      }
    }
  }

  Future<CanvasDocument?> loadDocument(String id) async {
    final repo = _ref.read(canvasRepositoryProvider);
    return await repo.loadDocument(id);
  }

  CanvasDocument updateDocumentFrame({
    required CanvasDocument document,
    required List<Shape> shapes,
    String? layerId,
    int? frameIndex,
  }) {
    return document.updateFrame(
      layerId: layerId ?? document.layers.first.id,
      frameIndex: frameIndex ?? 0,
      shapes: shapes,
    );
  }

  CanvasDocument addLayerToDocument({
    required CanvasDocument document,
    required String layerId,
    String? name,
    required int frameIndex,
  }) {
    final layer = CanvasLayer(
      id: layerId,
      name: name ?? 'Layer $_layerCounter',
      frames: {frameIndex: CanvasFrame(index: frameIndex)},
    );
    final nextFrameCount = frameIndex >= document.frameCount
        ? frameIndex + 1
        : document.frameCount;
    return document
        .upsertLayer(layer)
        .copyWith(updatedAt: DateTime.now(), frameCount: nextFrameCount);
  }

  CanvasDocument toggleLayerVisibility({
    required CanvasDocument document,
    required String layerId,
  }) {
    final layer = document.layerById(layerId);
    if (layer == null) return document;
    final updated = layer.copyWith(isVisible: !layer.isVisible);
    return document
        .upsertLayer(updated)
        .copyWith(updatedAt: DateTime.now());
  }

  CanvasDocument updateDocumentMetadata({
    required CanvasDocument document,
    String? title,
    Size? size,
    double? fps,
    int? frameCount,
    CanvasBackground? background,
  }) {
    return document.copyWith(
      title: title,
      size: size,
      background: background,
      fps: fps,
      frameCount: frameCount,
      updatedAt: DateTime.now(),
    );
  }

  void cancelAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _autosaveDirty = false;
  }

  void dispose() {
    _autosaveTimer?.cancel();
  }
}

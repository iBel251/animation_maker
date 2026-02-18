import 'dart:async';

import 'package:animation_maker/features/canvas/presentation/models/history_operation.dart';
import 'package:animation_maker/features/canvas/presentation/services/document_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/history_manager.dart';

/// View model for managing history operations (undo/redo)
class HistoryViewModel {
  HistoryViewModel({
    required DocumentService documentService,
  }) : _document = documentService;

  final DocumentService _document;

  bool _applyingHistory = false;
  bool _historyApplyInProgress = false;
  final List<HistoryOperation> _pendingHistoryQueue = [];
  Timer? _historyDebounceTimer;
  int _historyApplyGeneration = 0;

  bool get canUndo => _document.history.canUndo;
  bool get canRedo => _document.history.canRedo;
  bool get isHistoryBusy => _historyApplyInProgress || _applyingHistory;
  bool get applyingHistory => _applyingHistory;
  int get applyGeneration => _historyApplyGeneration;

  Future<HistorySnapshot?> undo() {
    final snap = _document.undo();
    if (snap == null) return Future.value(null);
    return Future.value(snap);
  }

  Future<HistorySnapshot?> redo() {
    final snap = _document.redo();
    if (snap == null) return Future.value(null);
    return Future.value(snap);
  }

  void scheduleHistoryApply(
    HistorySnapshot snap,
    HistoryOperationType type,
    Function(HistorySnapshot) onApply,
  ) {
    _historyDebounceTimer?.cancel();
    
    _pendingHistoryQueue.add(HistoryOperation(snapshot: snap, type: type));
    
    _historyDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _processHistoryQueue(onApply);
    });
  }

  Future<void> _processHistoryQueue(Function(HistorySnapshot) onApply) async {
    if (_historyApplyInProgress) {
      return;
    }
    
    if (_pendingHistoryQueue.isEmpty) return;
    
    final currentGeneration = ++_historyApplyGeneration;
    _historyApplyInProgress = true;
    
    try {
      while (_pendingHistoryQueue.isNotEmpty) {
        if (isHistoryApplyStale(currentGeneration)) {
          break;
        }
        
        final operation = _pendingHistoryQueue.removeAt(0);
        onApply(operation.snapshot);
      }
    } finally {
      _historyApplyInProgress = false;
      _historyDebounceTimer = null;
      
      if (_pendingHistoryQueue.isNotEmpty) {
        _historyDebounceTimer = Timer(const Duration(milliseconds: 50), () {
          _processHistoryQueue(onApply);
        });
      }
    }
  }

  bool isHistoryApplyStale(int generation) =>
      generation != _historyApplyGeneration;

  void setApplyingHistory(bool value) {
    _applyingHistory = value;
  }

  void cancelPending() {
    _historyDebounceTimer?.cancel();
    _pendingHistoryQueue.clear();
  }
}

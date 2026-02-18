import 'package:animation_maker/features/canvas/presentation/services/history_manager.dart';

enum HistoryOperationType { undo, redo }

class HistoryOperation {
  final HistorySnapshot snapshot;
  final HistoryOperationType type;
  
  HistoryOperation({required this.snapshot, required this.type});
}

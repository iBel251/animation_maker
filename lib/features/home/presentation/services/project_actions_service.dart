import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';

/// Service for handling project actions: delete, duplicate, rename.
/// Provides a clean interface for project management operations.
class ProjectActionsService {
  ProjectActionsService(this._repository);

  final CanvasRepository _repository;

  /// Deletes a project by its ID.
  /// Returns true if deletion was successful.
  Future<bool> deleteProject(String projectId) async {
    try {
      await _repository.deleteDocument(projectId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Duplicates a project and returns the new project's ID.
  /// Returns null if duplication failed.
  Future<String?> duplicateProject(String projectId) async {
    try {
      // Load the original document
      final original = await _repository.loadDocument(projectId);
      if (original == null) return null;

      // Create a new ID for the duplicate
      final newId = _generateId();
      final now = DateTime.now();

      // Create the duplicated document with a new title using copyWith
      final duplicate = original.copyWith(
        id: newId,
        title: '${original.title} (Copy)',
        createdAt: now,
        updatedAt: now,
      );

      // Save the duplicate
      await _repository.saveDocument(duplicate);
      return newId;
    } catch (e) {
      return null;
    }
  }

  /// Renames a project.
  /// Returns true if rename was successful.
  Future<bool> renameProject(String projectId, String newTitle) async {
    try {
      // Load the document
      final document = await _repository.loadDocument(projectId);
      if (document == null) return false;

      // Update the title using copyWith
      final updated = document.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );

      // Save the updated document
      await _repository.saveDocument(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generates a unique ID for new documents.
  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}

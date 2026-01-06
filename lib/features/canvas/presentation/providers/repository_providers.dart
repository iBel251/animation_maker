import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/features/canvas/data/db/canvas_database.dart';
import 'package:animation_maker/features/canvas/data/repositories/canvas_repository_impl.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:animation_maker/features/canvas/data/datasources/canvas_local_datasource.dart';

final canvasDatabaseProvider = Provider<CanvasDatabase>((ref) {
  final database = CanvasDatabase();
  ref.onDispose(database.close);
  return database;
});

final canvasRepositoryProvider = Provider<CanvasRepository>((ref) {
  final database = ref.read(canvasDatabaseProvider);
  return CanvasRepositoryImpl(
    localDataSource: CanvasLocalDataSource(database: database),
  );
});

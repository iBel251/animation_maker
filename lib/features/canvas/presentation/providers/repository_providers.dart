import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/features/canvas/data/repositories/canvas_repository_impl.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';

final canvasRepositoryProvider = Provider<CanvasRepository>((ref) {
  return CanvasRepositoryImpl();
});

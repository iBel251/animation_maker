import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/image_service.dart';

/// Global singleton [ImageService] provider.
///
/// Manages image picking, file persistence, and dart:ui.Image caching.
/// Disposed automatically when the provider scope is destroyed.
final imageServiceProvider = Provider<ImageService>((ref) {
  final service = ImageService();
  ref.onDispose(() => service.dispose());
  return service;
});

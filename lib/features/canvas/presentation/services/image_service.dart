import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of picking and persisting an image.
class ImagePickResult {
  const ImagePickResult({
    required this.relativePath,
    required this.originalSize,
  });

  final String relativePath;
  final ui.Size originalSize;
}

/// Service for image picking, file persistence, and dart:ui.Image caching.
///
/// Images are copied to a stable app documents subdirectory so paths remain
/// valid across sessions. A bounded LRU cache keeps decoded [ui.Image]
/// objects in memory for synchronous access during [CustomPainter.paint].
class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final Map<String, ui.Image> _imageCache = {};
  static const int _maxCacheEntries = 50;
  String? _imagesDirPath;

  /// Lazily resolved directory for persisted images.
  Future<String> get _imagesDir async {
    if (_imagesDirPath != null) return _imagesDirPath!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'animation_maker', 'images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _imagesDirPath = dir.path;
    return dir.path;
  }

  /// Picks an image from the gallery and copies it to app storage.
  ///
  /// Returns `null` if the user cancels the picker.
  Future<ImagePickResult?> pickAndPersistImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final imagesDir = await _imagesDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.png';
    final fileName = 'img_$timestamp$ext';
    final destPath = p.join(imagesDir, fileName);

    // Copy file to stable location
    final sourceFile = File(picked.path);
    await sourceFile.copy(destPath);

    // Decode to get original dimensions and cache
    final bytes = await File(destPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = ui.Size(image.width.toDouble(), image.height.toDouble());

    final relativePath = 'images/$fileName';
    _putCache(relativePath, image);

    return ImagePickResult(relativePath: relativePath, originalSize: size);
  }

  /// Persists raw image bytes to app storage and returns the relative path.
  ///
  /// The bytes are expected to be a valid encoded image format (typically PNG).
  Future<String> persistImageBytes(
    Uint8List bytes, {
    String filePrefix = 'img',
    String extension = '.png',
  }) async {
    final imagesDir = await _imagesDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedExt = extension.startsWith('.') ? extension : '.$extension';
    final fileName = '${filePrefix}_$timestamp$normalizedExt';
    final destPath = p.join(imagesDir, fileName);
    final file = File(destPath);
    await file.writeAsBytes(bytes, flush: true);
    return 'images/$fileName';
  }

  /// Loads a [ui.Image] from a relative path. Returns cached if available.
  ///
  /// Returns `null` if the file does not exist or decoding fails.
  Future<ui.Image?> loadImage(String relativePath) async {
    final cached = _imageCache[relativePath];
    if (cached != null) return cached;

    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = p.join(appDir.path, 'animation_maker', relativePath);
    final file = File(fullPath);
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _putCache(relativePath, image);
      return image;
    } catch (e) {
      debugPrint('ImageService: failed to load $relativePath: $e');
      return null;
    }
  }

  /// Synchronous cache lookup for use inside [CustomPainter.paint].
  ui.Image? getCachedImage(String relativePath) {
    return _imageCache[relativePath];
  }

  /// Pre-loads all given image paths into the cache.
  Future<void> preloadImages(Iterable<String> relativePaths) async {
    final futures = <Future>[];
    for (final path in relativePaths) {
      if (!_imageCache.containsKey(path)) {
        futures.add(loadImage(path));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void _putCache(String key, ui.Image image) {
    if (_imageCache.length >= _maxCacheEntries) {
      final oldestKey = _imageCache.keys.first;
      _imageCache.remove(oldestKey)?.dispose();
    }
    _imageCache[key] = image;
  }

  /// Disposes all cached images. Call on app shutdown.
  void dispose() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
  }
}

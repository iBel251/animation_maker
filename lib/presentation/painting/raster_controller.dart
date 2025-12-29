import 'dart:ui';

import 'package:animation_maker/presentation/painting/raster_engine.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';

class RasterController {
  RasterController({RasterEngine? engine}) : _engine = engine ?? RasterEngine();

  final RasterEngine _engine;
  final List<RasterStroke> _strokes = [];

  Image? get image => _engine.image;
  List<RasterStroke> get strokes => List<RasterStroke>.unmodifiable(_strokes);

  void updateSize(Size size) {
    _engine.updateSize(size);
  }

  Future<Image?> addStroke(RasterStroke stroke) async {
    _strokes.add(stroke);
    return _engine.renderStrokes(_strokes);
  }

  Future<Image?> renderAll() async {
    return _engine.renderStrokes(_strokes);
  }

  void reset() {
    _strokes.clear();
    _engine.clear();
  }

  void replaceStrokes(List<RasterStroke> strokes) {
    _strokes
      ..clear()
      ..addAll(strokes);
  }
}

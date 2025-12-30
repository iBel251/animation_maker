import 'dart:ui';

import 'package:animation_maker/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/presentation/painting/raster_engine.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';

class RasterController {
  RasterController({RasterEngine? engine, BrushRenderer? renderer})
      : _engine = engine ??
            RasterEngine(renderer: renderer ?? const PerfectFreehandRenderer());

  final RasterEngine _engine;
  final List<RasterStroke> _strokes = [];

  Image? get image => _engine.image;
  List<RasterStroke> get strokes => List<RasterStroke>.unmodifiable(_strokes);

  void updateSize(Size size) {
    _engine.updateSize(size);
  }

  Future<Image?> addStroke(RasterStroke stroke) async {
    _strokes.add(stroke);
    final incremental = await _engine.renderStrokeIncremental(stroke);
    if (incremental != null) return incremental;
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

# Vector Stroke System: Production-Level Improvement Plan

## Executive Summary

This document outlines a comprehensive plan to improve the vector drawing functionality in the Animation Maker app. The current implementation has a solid foundation with immutable shapes, a brush registry pattern, and pressure-aware strokes. However, several areas need enhancement for production-level quality.

---

## Current Architecture Analysis

### Data Flow
```
Touch Input → StrokeInputProcessor → BrushStrokeFactory → Shape Entity → CanvasPainter
```

### Strengths ✅
- Clean separation of concerns (input → storage → rendering)
- Immutable Shape design enables efficient dirty tracking
- Extensible BrushRendererRegistry pattern
- Pressure-aware stroke system with fallback
- Transform system supports rotation, pivot, and flip operations

### Weaknesses ❌
- **Unused One Euro Filter** - Temporal smoothing is defined but not applied
- **Deterministic jitter** - Pencil brush uses coordinate-based hash (not truly random)
- **Perfect Freehand dependency** - Black-box external dependency with no fallback
- **Undefined brush types** - hair, cube, gradient, mosaic are registered but have no renderers
- **No real-time stroke preview** - Strokes only render on finish
- **Limited customization** - No dashes, textures, or advanced effects
- **Transform recalculation** - Matrix4 operations repeat every paint cycle

---

## Phase 1: Immediate Improvements (Foundation)

### 1.1 Enable Temporal Smoothing (One Euro Filter)

**Problem**: `StrokeSmoother` class exists but is not integrated into the stroke pipeline.

**Solution**: Integrate One Euro Filter into `StrokeInputProcessor`

```dart
// stroke_input_processor.dart - PROPOSED CHANGES

class StrokeInputProcessor {
  final StrokeSmoother _smoother = StrokeSmoother();

  void startStroke(Offset point, double pressure, {double smoothness = 0.5}) {
    _smoother.reset();
    _smoother.smoothness = smoothness;
    // ... existing code
  }

  List<PointVector> processPoint(Offset rawPoint, double pressure) {
    // Apply temporal smoothing BEFORE geometric sampling
    final smoothedPoint = _smoother.smooth(rawPoint);
    final smoothedPressure = _pressureSmoother.filter(pressure);

    // Continue with existing quadratic sampling...
  }
}
```

**Files to modify**:
- [stroke_input_processor.dart](lib/features/canvas/presentation/services/stroke_input_processor.dart)
- [stroke_smoothing.dart](lib/features/canvas/presentation/painting/stroke_smoothing.dart)

**Benefits**:
- Removes high-frequency jitter from stylus input
- Adaptive smoothing based on stroke velocity
- Configurable per-stroke smoothness

---

### 1.2 Implement Real-Time Stroke Preview

**Problem**: Strokes only appear after touch ends.

**Solution**: Add progressive stroke rendering during input

```dart
// NEW: stroke_preview_controller.dart

class StrokePreviewController {
  final List<PointVector> _previewPoints = [];
  ui.Path? _cachedPath;
  bool _isDirty = true;

  void addPoint(PointVector point) {
    _previewPoints.add(point);
    _isDirty = true;
    // Only rebuild last segment for performance
  }

  ui.Path buildIncrementalPath(BrushRenderer renderer, BrushStrokeOptions options) {
    if (!_isDirty && _cachedPath != null) return _cachedPath!;

    // Build path from last N points only (incremental)
    final recentPoints = _previewPoints.length > 10
        ? _previewPoints.sublist(_previewPoints.length - 10)
        : _previewPoints;

    _cachedPath = renderer.buildPath(recentPoints, options);
    _isDirty = false;
    return _cachedPath!;
  }
}
```

**Integration**:
- `CanvasPainter` checks for active stroke preview
- Renders preview with slight transparency
- Finalizes to Shape on stroke end

---

### 1.3 Add Pressure Smoothing

**Problem**: Raw pressure values create jittery stroke widths.

**Solution**: Apply low-pass filter to pressure values

```dart
// pressure_filter.dart

class PressureFilter {
  double _lastPressure = 0.5;
  final double smoothingFactor;

  PressureFilter({this.smoothingFactor = 0.3});

  double filter(double rawPressure) {
    _lastPressure = _lastPressure + smoothingFactor * (rawPressure - _lastPressure);
    return _lastPressure;
  }

  void reset() => _lastPressure = 0.5;
}
```

---

## Phase 2: Brush System Enhancements

### 2.1 New Brush Architecture

**Problem**: Current `BrushRenderer` interface is too limited.

**Solution**: Enhanced brush system with more customization points

```dart
// NEW: enhanced_brush_renderer.dart

abstract class EnhancedBrushRenderer {
  /// Core path generation
  ui.Path? buildPath(List<PointVector> points, BrushStrokeOptions options);

  /// Pre-processing of input points (jitter, offset, etc.)
  List<PointVector> preprocessPoints(List<PointVector> points, BrushStrokeOptions options) => points;

  /// Post-processing of generated path (simplification, effects)
  ui.Path postprocessPath(ui.Path path, BrushStrokeOptions options) => path;

  /// Paint customization (beyond simple color)
  ui.Paint configurePaint(ui.Paint paint, BrushStrokeOptions options) => paint;

  /// Whether this brush supports real-time preview
  bool get supportsPreview => true;

  /// Minimum points required for rendering
  int get minimumPoints => 2;

  /// Brush-specific metadata for UI
  BrushMetadata get metadata;
}

class BrushMetadata {
  final String name;
  final String description;
  final IconData icon;
  final List<BrushParameter> parameters;

  const BrushMetadata({
    required this.name,
    required this.description,
    required this.icon,
    this.parameters = const [],
  });
}

class BrushParameter {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;

  const BrushParameter({...});
}
```

---

### 2.2 Implement Missing Brush Types

#### Hair Brush
```dart
class HairBrushRenderer extends EnhancedBrushRenderer {
  @override
  List<PointVector> preprocessPoints(List<PointVector> points, BrushStrokeOptions options) {
    // Generate multiple hair strands from single stroke
    final strands = <PointVector>[];
    final random = Random(points.hashCode); // Deterministic per-stroke

    for (int strand = 0; strand < 5; strand++) {
      for (final point in points) {
        final offset = Offset(
          (random.nextDouble() - 0.5) * options.size * 0.3,
          (random.nextDouble() - 0.5) * options.size * 0.3,
        );
        strands.add(PointVector.fromOffset(
          Offset(point.x, point.y) + offset,
          point.pressure ?? 0.5 * (0.5 + random.nextDouble() * 0.5),
        ));
      }
    }
    return strands;
  }

  @override
  ui.Paint configurePaint(ui.Paint paint, BrushStrokeOptions options) {
    return paint
      ..strokeWidth = options.size * 0.15 // Thin strands
      ..strokeCap = StrokeCap.round;
  }
}
```

#### Gradient Brush
```dart
class GradientBrushRenderer extends EnhancedBrushRenderer {
  @override
  ui.Paint configurePaint(ui.Paint paint, BrushStrokeOptions options) {
    // Create gradient along stroke direction
    final gradient = ui.Gradient.linear(
      options.startPoint ?? Offset.zero,
      options.endPoint ?? const Offset(100, 0),
      [options.color, options.secondaryColor ?? options.color.withOpacity(0.2)],
    );
    return paint..shader = gradient;
  }
}
```

#### Texture Brush (Mosaic/Cube)
```dart
class TextureBrushRenderer extends EnhancedBrushRenderer {
  final ui.Image? texture;

  @override
  ui.Paint configurePaint(ui.Paint paint, BrushStrokeOptions options) {
    if (texture != null) {
      final shader = ImageShader(
        texture!,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
      return paint..shader = shader;
    }
    return paint;
  }
}
```

---

### 2.3 Brush Parameters System

**New**: Allow per-brush configurable parameters

```dart
// brush_options.dart

class BrushStrokeOptions {
  final double size;
  final Color color;
  final double smoothing;
  final double streamline;
  final double thinning;
  final bool simulatePressure;

  // NEW: Extensible parameters
  final Map<String, dynamic> customParameters;

  // Convenience accessors
  double get jitterAmount => customParameters['jitter'] as double? ?? 0.0;
  double get opacity => customParameters['opacity'] as double? ?? 1.0;
  int get hairCount => customParameters['hairCount'] as int? ?? 5;
  Color? get secondaryColor => customParameters['secondaryColor'] as Color?;
}
```

---

## Phase 3: Performance Optimizations

### 3.1 Path Caching Strategy

**Problem**: Paths are regenerated every paint cycle.

**Solution**: Cache rendered paths with invalidation

```dart
// path_cache.dart

class PathCache {
  final Map<String, _CachedPath> _cache = {};

  ui.Path? getPath(Shape shape) {
    final key = _computeKey(shape);
    final cached = _cache[key];

    if (cached != null && !_isStale(cached, shape)) {
      return cached.path;
    }
    return null;
  }

  void cachePath(Shape shape, ui.Path path) {
    final key = _computeKey(shape);
    _cache[key] = _CachedPath(
      path: path,
      transformHash: shape.transform.hashCode,
      pointsHash: shape.points.hashCode,
      timestamp: DateTime.now(),
    );
  }

  String _computeKey(Shape shape) => '${shape.id}_${shape.transform.hashCode}';

  bool _isStale(_CachedPath cached, Shape shape) {
    return cached.transformHash != shape.transform.hashCode ||
           cached.pointsHash != shape.points.hashCode;
  }

  void evictOldEntries({Duration maxAge = const Duration(minutes: 5)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _cache.removeWhere((_, v) => v.timestamp.isBefore(cutoff));
  }
}
```

---

### 3.2 Transform Matrix Caching

**Problem**: Matrix4 operations are expensive and repeated.

**Solution**: Cache transform matrices in Shape

```dart
// shape.dart - PROPOSED CHANGES

class Shape {
  // Existing fields...

  // Cached matrix (computed lazily)
  Matrix4? _cachedMatrix;
  int? _transformHash;

  Matrix4 get worldMatrix {
    final currentHash = transform.hashCode;
    if (_cachedMatrix == null || _transformHash != currentHash) {
      _cachedMatrix = transform.matrixWithOrigin(Offset.zero);
      _transformHash = currentHash;
    }
    return _cachedMatrix!;
  }
}
```

---

### 3.3 Level of Detail (LOD) System

**Problem**: Complex strokes render fully even when zoomed out.

**Solution**: Dynamic point reduction based on zoom level

```dart
// lod_processor.dart

class LODProcessor {
  /// Simplify points based on current zoom level
  List<PointVector> simplifyForZoom(List<PointVector> points, double zoomLevel) {
    if (zoomLevel >= 1.0) return points; // Full detail at 100%+

    // Ramer-Douglas-Peucker simplification
    final epsilon = 2.0 / zoomLevel; // Larger epsilon = more simplification
    return _rdpSimplify(points, epsilon);
  }

  List<PointVector> _rdpSimplify(List<PointVector> points, double epsilon) {
    if (points.length < 3) return points;

    // Find point with maximum distance from line segment
    double maxDist = 0;
    int maxIndex = 0;

    final start = Offset(points.first.x, points.first.y);
    final end = Offset(points.last.x, points.last.y);

    for (int i = 1; i < points.length - 1; i++) {
      final point = Offset(points[i].x, points[i].y);
      final dist = _perpendicularDistance(point, start, end);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _rdpSimplify(points.sublist(0, maxIndex + 1), epsilon);
      final right = _rdpSimplify(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [points.first, points.last];
  }
}
```

---

## Phase 4: Advanced Features

### 4.1 Stroke Effects System

```dart
// stroke_effect.dart

abstract class StrokeEffect {
  ui.Path apply(ui.Path path, StrokeEffectOptions options);
}

class DashEffect extends StrokeEffect {
  @override
  ui.Path apply(ui.Path path, StrokeEffectOptions options) {
    final dashPath = ui.Path();
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;

      while (distance < metric.length) {
        final length = draw ? options.dashLength : options.gapLength;
        final extractLength = math.min(length, metric.length - distance);

        if (draw) {
          final extracted = metric.extractPath(distance, distance + extractLength);
          dashPath.addPath(extracted, Offset.zero);
        }

        distance += extractLength;
        draw = !draw;
      }
    }

    return dashPath;
  }
}

class TaperEffect extends StrokeEffect {
  @override
  ui.Path apply(ui.Path path, StrokeEffectOptions options) {
    // Apply start/end taper to stroke
  }
}

class RoughenEffect extends StrokeEffect {
  @override
  ui.Path apply(ui.Path path, StrokeEffectOptions options) {
    // Add hand-drawn roughness to path edges
  }
}
```

---

### 4.2 Bezier-Based Stroke Storage

**Problem**: Storing raw points uses more memory and loses curve information.

**Solution**: Convert strokes to Bezier curves for efficient storage

```dart
// bezier_stroke.dart

class BezierStroke {
  final List<CubicBezier> segments;
  final List<double> pressures; // Pressure at each control point

  /// Convert point list to optimized Bezier representation
  static BezierStroke fromPoints(List<PointVector> points) {
    if (points.length < 2) return BezierStroke(segments: [], pressures: []);

    final segments = <CubicBezier>[];
    final pressures = <double>[];

    // Fit cubic Bezier curves through points
    // Using least-squares fitting algorithm

    for (int i = 0; i < points.length - 1; i += 3) {
      final endIndex = math.min(i + 3, points.length - 1);
      final segment = _fitCubicBezier(points.sublist(i, endIndex + 1));
      segments.add(segment);
      pressures.addAll([
        points[i].pressure ?? 0.5,
        (points[i].pressure ?? 0.5 + points[endIndex].pressure ?? 0.5) / 2,
        (points[i].pressure ?? 0.5 + points[endIndex].pressure ?? 0.5) / 2,
        points[endIndex].pressure ?? 0.5,
      ]);
    }

    return BezierStroke(segments: segments, pressures: pressures);
  }

  /// Sample points from Bezier at given density
  List<PointVector> samplePoints({int samplesPerSegment = 10}) {
    final points = <PointVector>[];

    for (int s = 0; s < segments.length; s++) {
      final segment = segments[s];
      for (int i = 0; i <= samplesPerSegment; i++) {
        final t = i / samplesPerSegment;
        final point = segment.pointAt(t);
        final pressure = _interpolatePressure(s, t);
        points.add(PointVector.fromOffset(point, pressure));
      }
    }

    return points;
  }
}

class CubicBezier {
  final Offset p0, p1, p2, p3;

  Offset pointAt(double t) {
    final mt = 1 - t;
    return p0 * (mt * mt * mt) +
           p1 * (3 * mt * mt * t) +
           p2 * (3 * mt * t * t) +
           p3 * (t * t * t);
  }
}
```

**Benefits**:
- 60-80% reduction in point storage
- Resolution-independent rendering
- Easier to edit/manipulate curves
- Better compatibility with vector formats (SVG export)

---

### 4.3 Native Perfect Freehand Implementation

**Problem**: External dependency on `perfect_freehand` package.

**Solution**: Implement core algorithm natively for control and optimization

```dart
// native_freehand.dart

class NativeFreehand {
  /// Generate outline points for a pressure-sensitive stroke
  static List<Offset> getStroke(
    List<PointVector> points, {
    double size = 16,
    double thinning = 0.5,
    double smoothing = 0.5,
    double streamline = 0.5,
    bool simulatePressure = true,
    double start = 0.1,
    double end = 0.1,
    bool isComplete = true,
  }) {
    if (points.isEmpty) return [];
    if (points.length == 1) {
      return _getCircle(Offset(points[0].x, points[0].y), size / 2);
    }

    // 1. Process input points with streamline
    final processedPoints = _streamlinePoints(points, streamline);

    // 2. Calculate running length for taper
    final lengths = _calculateLengths(processedPoints);
    final totalLength = lengths.last;

    // 3. Generate left and right edge points
    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    for (int i = 0; i < processedPoints.length; i++) {
      final point = processedPoints[i];
      final pressure = simulatePressure
          ? _simulatePressure(lengths[i], totalLength)
          : (point.pressure ?? 0.5);

      // Apply thinning based on pressure
      final radius = size / 2 * (1 - thinning + thinning * pressure);

      // Apply taper
      final taperStart = start > 0 ? _easeInOut(lengths[i] / (totalLength * start)) : 1.0;
      final taperEnd = end > 0 ? _easeInOut((totalLength - lengths[i]) / (totalLength * end)) : 1.0;
      final taper = math.min(taperStart, taperEnd).clamp(0.0, 1.0);

      final adjustedRadius = radius * taper;

      // Calculate perpendicular direction
      final direction = i < processedPoints.length - 1
          ? _normalize(Offset(
              processedPoints[i + 1].x - point.x,
              processedPoints[i + 1].y - point.y,
            ))
          : _normalize(Offset(
              point.x - processedPoints[i - 1].x,
              point.y - processedPoints[i - 1].y,
            ));

      final perpendicular = Offset(-direction.dy, direction.dx);
      final center = Offset(point.x, point.y);

      leftPoints.add(center + perpendicular * adjustedRadius);
      rightPoints.add(center - perpendicular * adjustedRadius);
    }

    // 4. Combine into closed outline
    return [
      ...leftPoints,
      ..._getEndCap(processedPoints.last, rightPoints.last, leftPoints.last, size * 0.1),
      ...rightPoints.reversed,
      ..._getStartCap(processedPoints.first, leftPoints.first, rightPoints.first, size * 0.1),
    ];
  }

  static List<PointVector> _streamlinePoints(List<PointVector> points, double streamline) {
    if (streamline == 0) return points;

    final result = <PointVector>[points.first];
    var prev = points.first;

    for (int i = 1; i < points.length; i++) {
      final curr = points[i];
      final x = prev.x + (curr.x - prev.x) * (1 - streamline);
      final y = prev.y + (curr.y - prev.y) * (1 - streamline);
      final p = (prev.pressure ?? 0.5) + ((curr.pressure ?? 0.5) - (prev.pressure ?? 0.5)) * (1 - streamline);

      final newPoint = PointVector.fromOffset(Offset(x, y), p);
      result.add(newPoint);
      prev = newPoint;
    }

    return result;
  }

  static double _easeInOut(double t) {
    return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
  }
}
```

---

## Phase 5: Future-Proofing

### 5.1 SVG Import/Export

```dart
// svg_stroke_converter.dart

class SVGStrokeConverter {
  /// Export Shape to SVG path data
  static String toSVGPath(Shape shape) {
    final points = shape.points;
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write('M ${points.first.dx} ${points.first.dy}');

    // Convert to smooth cubic beziers
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];

      // Calculate control points for smooth curve
      final c1 = Offset(
        p0.dx + (p1.dx - p0.dx) * 0.5,
        p0.dy + (p1.dy - p0.dy) * 0.5,
      );
      final c2 = Offset(
        p1.dx - (p2.dx - p0.dx) * 0.15,
        p1.dy - (p2.dy - p0.dy) * 0.15,
      );

      buffer.write(' C ${c1.dx} ${c1.dy}, ${c2.dx} ${c2.dy}, ${p1.dx} ${p1.dy}');
    }

    if (shape.isClosed) buffer.write(' Z');

    return buffer.toString();
  }

  /// Import SVG path data to Shape
  static Shape fromSVGPath(String pathData, {Color color = Colors.black}) {
    // Parse SVG path commands and convert to points
    // ...
  }
}
```

---

### 5.2 Stroke Serialization v2

```dart
// Enhanced serialization with forward compatibility

class StrokeSerializerV2 {
  static const int version = 2;

  static Map<String, dynamic> serialize(Shape shape) {
    return {
      'version': version,
      'id': shape.id,
      'kind': shape.kind.name,

      // Efficient point storage (delta-encoded)
      'pointData': _encodePointsDelta(shape.points),
      'pressureData': shape.pointPressures != null
          ? _encodePressures(shape.pointPressures!)
          : null,

      // Visual properties
      'visual': {
        'strokeColor': shape.strokeColor.value,
        'strokeWidth': shape.strokeWidth,
        'fillColor': shape.fillColor?.value,
        'opacity': shape.opacity,
        'brushType': shape.brushType?.name,
      },

      // Transform (compact)
      'transform': _encodeTransform(shape.transform),

      // Extensible metadata
      'metadata': {
        'createdAt': DateTime.now().toIso8601String(),
        'brushVersion': '2.0',
      },

      // Future-proofing: unknown fields preserved
      'extensions': {},
    };
  }

  /// Delta encoding for points (reduces size by ~40%)
  static String _encodePointsDelta(List<Offset> points) {
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write('${points.first.dx.toStringAsFixed(2)},${points.first.dy.toStringAsFixed(2)}');

    for (int i = 1; i < points.length; i++) {
      final dx = points[i].dx - points[i - 1].dx;
      final dy = points[i].dy - points[i - 1].dy;
      buffer.write(';${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)}');
    }

    return buffer.toString();
  }
}
```

---

### 5.3 Plugin Architecture for Custom Brushes

```dart
// brush_plugin.dart

abstract class BrushPlugin {
  String get id;
  String get name;
  String get version;

  BrushMetadata get metadata;
  EnhancedBrushRenderer createRenderer();

  /// Custom UI for brush settings (optional)
  Widget? buildSettingsUI(BuildContext context, BrushStrokeOptions options);

  /// Serialization for brush-specific data
  Map<String, dynamic> serializeSettings(BrushStrokeOptions options);
  BrushStrokeOptions deserializeSettings(Map<String, dynamic> data);
}

class BrushPluginManager {
  final Map<String, BrushPlugin> _plugins = {};

  void registerPlugin(BrushPlugin plugin) {
    _plugins[plugin.id] = plugin;
    BrushRendererRegistry.instance.register(
      BrushType.values.firstWhere((t) => t.name == plugin.id),
      () => plugin.createRenderer(),
    );
  }

  List<BrushPlugin> get availablePlugins => _plugins.values.toList();
}
```

---

## Implementation Priority

### High Priority (Week 1-2)
1. ✅ Enable One Euro Filter temporal smoothing
2. ✅ Add pressure smoothing
3. ✅ Implement real-time stroke preview
4. ✅ Add path caching

### Medium Priority (Week 3-4)
5. Implement Hair, Gradient brush types
6. Add stroke effects system (dash, taper)
7. Transform matrix caching
8. LOD system for zoom performance

### Lower Priority (Week 5+)
9. Native Perfect Freehand implementation
10. Bezier-based stroke storage
11. SVG import/export
12. Plugin architecture
13. Serialization v2 with delta encoding

---

## File Structure (Proposed)

```
lib/features/canvas/
├── domain/
│   ├── entities/
│   │   ├── shape.dart                    # Enhanced with matrix caching
│   │   └── bezier_stroke.dart           # NEW: Bezier representation
│   └── services/
│       └── stroke_simplifier.dart        # NEW: LOD/RDP simplification
│
├── presentation/
│   ├── painting/
│   │   ├── brush_renderer.dart           # Enhanced interface
│   │   ├── brush_renderer_registry.dart  # Existing
│   │   ├── brush_stroke_factory.dart     # Existing
│   │   ├── stroke_smoothing.dart         # Enhanced with integration
│   │   ├── stroke_render_config.dart     # Existing
│   │   ├── native_freehand.dart          # NEW: Native implementation
│   │   ├── path_cache.dart               # NEW: Path caching
│   │   └── brushes/
│   │       ├── perfect_freehand_brush.dart
│   │       ├── marker_brush.dart
│   │       ├── pencil_brush.dart
│   │       ├── hair_brush.dart           # NEW
│   │       ├── gradient_brush.dart       # NEW
│   │       └── texture_brush.dart        # NEW
│   │
│   ├── effects/
│   │   ├── stroke_effect.dart            # NEW: Effect base
│   │   ├── dash_effect.dart              # NEW
│   │   ├── taper_effect.dart             # NEW
│   │   └── roughen_effect.dart           # NEW
│   │
│   └── services/
│       ├── stroke_input_processor.dart   # Enhanced with smoothing
│       ├── stroke_drawing_service.dart   # Existing
│       └── stroke_preview_controller.dart # NEW: Real-time preview
│
└── data/
    └── serializers/
        ├── canvas_document_codec.dart    # Existing
        ├── stroke_serializer_v2.dart     # NEW: Enhanced format
        └── svg_converter.dart            # NEW: SVG support
```

---

## Testing Strategy

### Unit Tests
- Smoothing algorithm accuracy
- Bezier fitting quality
- Point simplification preservation
- Serialization round-trip

### Performance Tests
- 1000+ stroke rendering benchmark
- Memory usage with large documents
- Path cache hit rates
- LOD switching latency

### Visual Tests
- Brush type comparison renders
- Pressure sensitivity curves
- Effect visual verification
- Zoom level LOD transitions

---

## Conclusion

This improvement plan addresses the current weaknesses while maintaining the solid architectural foundation. The phased approach allows incremental improvements without breaking existing functionality. Key priorities are:

1. **Smoothing Integration** - Immediately improves stroke quality
2. **Real-time Preview** - Essential UX improvement
3. **Path Caching** - Significant performance gain
4. **Brush System Enhancement** - Enables future brush types
5. **Future-proofing** - SVG export, plugin architecture

The proposed changes are backward-compatible with existing document formats while enabling new capabilities for production-level vector drawing.

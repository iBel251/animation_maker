import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/path_simplifier.dart';
import 'package:animation_maker/features/canvas/domain/usecases/path_simplification.dart';
import 'package:animation_maker/features/canvas/presentation/painting/stroke_render_config.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Mode for combining paths during merge.
enum MergeMode {
  /// Combine all shapes into one (union of all areas).
  union,
  
  /// Keep only the overlapping area of all shapes.
  intersect,
  
  /// Subtract subsequent shapes from the first shape.
  difference,
  
  /// Keep only the non-overlapping areas (XOR).
  xor,
  
  /// Subtract the first shape from subsequent shapes.
  reverseDifference,
}

/// Extension to convert MergeMode to Flutter's PathOperation.
extension MergeModeX on MergeMode {
  PathOperation get pathOperation {
    switch (this) {
      case MergeMode.union:
        return PathOperation.union;
      case MergeMode.intersect:
        return PathOperation.intersect;
      case MergeMode.difference:
        return PathOperation.difference;
      case MergeMode.xor:
        return PathOperation.xor;
      case MergeMode.reverseDifference:
        return PathOperation.reverseDifference;
    }
  }
  
  /// User-friendly name for the mode.
  String get displayName {
    switch (this) {
      case MergeMode.union:
        return 'Union';
      case MergeMode.intersect:
        return 'Intersect';
      case MergeMode.difference:
        return 'Subtract';
      case MergeMode.xor:
        return 'Exclude';
      case MergeMode.reverseDifference:
        return 'Subtract Back';
    }
  }
  
  /// Description of what this mode does.
  String get description {
    switch (this) {
      case MergeMode.union:
        return 'Combine all shapes into one';
      case MergeMode.intersect:
        return 'Keep only overlapping areas';
      case MergeMode.difference:
        return 'Subtract other shapes from first';
      case MergeMode.xor:
        return 'Keep only non-overlapping areas';
      case MergeMode.reverseDifference:
        return 'Subtract first shape from others';
    }
  }
}

/// Reason why a shape was skipped during merge.
enum ShapeSkipReason {
  /// Shape has no points.
  noPoints,
  
  /// Shape has fewer than 2 points.
  tooFewPoints,
  
  /// Shape has invalid coordinates (NaN or Infinity).
  invalidCoordinates,
  
  /// Shape has zero or near-zero area.
  zeroArea,
  
  /// Shape bounds are too small (< 1px).
  tooSmall,
  
  /// Shape bounds could not be determined.
  noBounds,
  
  /// Path generation failed.
  pathGenerationFailed,
  
  /// Shape is not closed and was auto-closed for the merge operation.
  autoClosed,
}

/// Cache key for shape-to-path conversion.
class _PathCacheKey {
  const _PathCacheKey({
    required this.shapeId,
    required this.strokeScaleWithShape,
    required this.brushSmoothness,
  });

  final String shapeId;
  final bool strokeScaleWithShape;
  final double brushSmoothness;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PathCacheKey &&
          shapeId == other.shapeId &&
          strokeScaleWithShape == other.strokeScaleWithShape &&
          brushSmoothness == other.brushSmoothness;

  @override
  int get hashCode => Object.hash(shapeId, strokeScaleWithShape, brushSmoothness);
}

class ShapeMergeService {
  const ShapeMergeService();

  /// Minimum size in pixels for a shape to be valid for merging.
  static const double minShapeSize = 1.0;

  /// Validates a shape and returns a skip reason if invalid, null if valid.
  ShapeSkipReason? _validateShape(Shape shape) {
    // Check for empty points
    if (shape.points.isEmpty && shape.bounds == null) {
      return ShapeSkipReason.noPoints;
    }

    // Check for too few points (for point-based shapes)
    if (shape.kind == ShapeKind.freehand ||
        shape.kind == ShapeKind.line ||
        shape.kind == ShapeKind.polygon ||
        shape.kind == ShapeKind.pointPath) {
      if (shape.points.length < 2) {
        return ShapeSkipReason.tooFewPoints;
      }
    }

    // Check for invalid coordinates
    for (final point in shape.points) {
      if (point.dx.isNaN || point.dx.isInfinite ||
          point.dy.isNaN || point.dy.isInfinite) {
        return ShapeSkipReason.invalidCoordinates;
      }
    }

    // Check bezier point coordinates if present
    if (shape.bezierPoints != null) {
      for (final bp in shape.bezierPoints!) {
        if (bp.position.dx.isNaN || bp.position.dx.isInfinite ||
            bp.position.dy.isNaN || bp.position.dy.isInfinite) {
          return ShapeSkipReason.invalidCoordinates;
        }
        if (bp.controlIn != null &&
            (bp.controlIn!.dx.isNaN || bp.controlIn!.dx.isInfinite ||
             bp.controlIn!.dy.isNaN || bp.controlIn!.dy.isInfinite)) {
          return ShapeSkipReason.invalidCoordinates;
        }
        if (bp.controlOut != null &&
            (bp.controlOut!.dx.isNaN || bp.controlOut!.dx.isInfinite ||
             bp.controlOut!.dy.isNaN || bp.controlOut!.dy.isInfinite)) {
          return ShapeSkipReason.invalidCoordinates;
        }
      }
    }

    // Check bounds for rect/ellipse shapes
    if (shape.bounds != null) {
      final bounds = shape.bounds!;
      if (bounds.width.isNaN || bounds.width.isInfinite ||
          bounds.height.isNaN || bounds.height.isInfinite ||
          bounds.left.isNaN || bounds.left.isInfinite ||
          bounds.top.isNaN || bounds.top.isInfinite) {
        return ShapeSkipReason.invalidCoordinates;
      }

      // Check for zero area
      if (bounds.width <= 0 || bounds.height <= 0) {
        return ShapeSkipReason.zeroArea;
      }

      // Check for too small shapes
      if (bounds.width < minShapeSize && bounds.height < minShapeSize) {
        return ShapeSkipReason.tooSmall;
      }
    }

    // Check local bounds for point-based shapes
    final localBounds = shape.localBounds;
    if (localBounds != null) {
      if (localBounds.width <= 0 && localBounds.height <= 0) {
        return ShapeSkipReason.zeroArea;
      }
      if (localBounds.width < minShapeSize && localBounds.height < minShapeSize) {
        return ShapeSkipReason.tooSmall;
      }
    } else if (shape.bounds == null) {
      return ShapeSkipReason.noBounds;
    }

    return null; // Shape is valid
  }

  /// Simplifier for reducing point count in merged paths.
  static const PathSimplifier _simplifier = PathSimplifier();

  /// Default sample distance for path contour extraction.
  static const double defaultSampleDistance = 2.5;
  
  /// Minimum sample distance to avoid excessive points.
  static const double minSampleDistance = 1.0;
  
  /// Maximum sample distance to preserve detail.
  static const double maxSampleDistance = 10.0;

  /// Calculates an adaptive sample distance based on path bounds.
  /// 
  /// For larger shapes, uses a larger sample distance to avoid excessive points.
  /// For smaller shapes, uses a smaller sample distance to preserve detail.
  double _adaptiveSampleDistance(Path path) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return defaultSampleDistance;
    
    // Calculate based on the diagonal of the bounding box
    final diagonal = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height);
    
    // Use approximately 500-1000 samples per diagonal length
    // This provides good detail without excessive points
    final targetSamplesPerDiagonal = 750.0;
    final adaptiveDistance = diagonal / targetSamplesPerDiagonal;
    
    // Clamp to reasonable bounds
    return adaptiveDistance.clamp(minSampleDistance, maxSampleDistance);
  }

  /// Async version of merge with UI responsiveness handling.
  ///
  /// This method provides the same functionality as [merge] but with async handling
  /// that allows the UI to update (e.g., show processing indicators) for larger operations.
  /// 
  /// **Important Limitations:**
  /// - The actual path computation (`Path.combine`) runs on the main UI thread
  /// - Flutter's `dart:ui` `Path` objects cannot be transferred to isolates
  /// - The "async" nature is limited to yielding between operations, not true parallelism
  /// - For very large operations (100+ complex shapes), UI may still stutter
  /// 
  /// **Future Improvements:**
  /// - Consider using `compute()` with serializable path representations
  /// - Investigate chunked processing with periodic yields between path operations
  /// - Explore native path computation via FFI for heavy operations
  /// 
  /// [mode] specifies the path combination operation (default: union).
  /// [simplifyEpsilon] controls path simplification (0 = no simplification, default: 1.5).
  /// [sampleDistance] controls contour sampling (0 = use adaptive sampling based on shape size).
  Future<MergeResult> mergeAsync({
    required List<Shape> shapes,
    required List<String> selectedIds,
    required String Function() createId,
    bool strokeScaleWithShape = false,
    double brushSmoothness = 0.35,
    double sampleDistance = 0, // 0 = adaptive
    MergeMode mode = MergeMode.union,
    double simplifyEpsilon = 1.5,
  }) async {
    // For small selections (< 3 shapes), run synchronously
    // The async overhead isn't worth it for quick operations
    if (selectedIds.length < 3) {
      return merge(
        shapes: shapes,
        selectedIds: selectedIds,
        createId: createId,
        strokeScaleWithShape: strokeScaleWithShape,
        brushSmoothness: brushSmoothness,
        sampleDistance: sampleDistance,
        mode: mode,
        simplifyEpsilon: simplifyEpsilon,
      );
    }

    // Yield to allow UI to update (show processing indicator)
    // This gives the UI thread a chance to render the "processing" state
    await Future.delayed(const Duration(milliseconds: 1));

    // Run the merge operation
    // Note: Path.combine() runs on the main isolate because dart:ui Path
    // objects cannot be transferred between isolates. We yield control
    // to allow UI updates, but the computation itself blocks the main thread.
    final result = merge(
      shapes: shapes,
      selectedIds: selectedIds,
      createId: createId,
      strokeScaleWithShape: strokeScaleWithShape,
      brushSmoothness: brushSmoothness,
      sampleDistance: sampleDistance,
      mode: mode,
      simplifyEpsilon: simplifyEpsilon,
    );

    // Yield again after completion to allow UI to update
    await Future.delayed(Duration.zero);

    return result;
  }

  /// Merges shapes using the specified path operation mode.
  /// 
  /// [mode] specifies the path combination operation (default: union).
  /// [simplifyEpsilon] controls path simplification (0 = no simplification, default: 1.5).
  /// [sampleDistance] controls contour sampling (0 = use adaptive sampling based on shape size).
  MergeResult merge({
    required List<Shape> shapes,
    required List<String> selectedIds,
    required String Function() createId,
    bool strokeScaleWithShape = false,
    double brushSmoothness = 0.35,
    double sampleDistance = 0, // 0 = adaptive
    MergeMode mode = MergeMode.union,
    double simplifyEpsilon = 1.5,
  }) {
    if (selectedIds.length < 2) return const MergeResult.empty();
    if (shapes.isEmpty) return const MergeResult.empty();

    final idSet = selectedIds.toSet();
    final selectedShapes =
        shapes.where((shape) => idSet.contains(shape.id)).toList();
    if (selectedShapes.length < 2) return const MergeResult.empty();

    final styleSource = _findStyleSource(selectedIds, shapes, selectedShapes);
    final paths = <Path>[];
    final mergedSourceIds = <String>[];
    final skippedShapes = <SkippedShape>[];
    var usedStrokeOutline = false;
    var hasCurvedShapes = false; // Track if any shapes have Bezier curves

    // Local path cache for this merge operation
    // Useful for preview mode or batch operations where shapes might be processed multiple times
    final pathCache = <_PathCacheKey, _PathResult>{};

    // For intersect/difference modes, we need closed shapes for proper results.
    // Force-close non-closed shapes to avoid unexpected stroke outlines.
    final forceClose = mode != MergeMode.union;

    for (final shape in selectedShapes) {
      // Track if this shape has bezier curves for finer sampling later
      if (shape.hasBezierCurves) {
        hasCurvedShapes = true;
      }
      // Validate shape before processing
      final validationError = _validateShape(shape);
      if (validationError != null) {
        skippedShapes.add(SkippedShape(id: shape.id, reason: validationError));
        continue;
      }

      // Check cache first
      final cacheKey = _PathCacheKey(
        shapeId: shape.id,
        strokeScaleWithShape: strokeScaleWithShape,
        brushSmoothness: brushSmoothness,
      );
      
      var result = pathCache[cacheKey];
      if (result == null) {
        result = _pathForShape(
          shape: shape,
          strokeScaleWithShape: strokeScaleWithShape,
          brushSmoothness: brushSmoothness,
          forceClose: forceClose,
        );
        if (result != null) {
          pathCache[cacheKey] = result;
        }
      }
      
      if (result == null) {
        skippedShapes.add(SkippedShape(id: shape.id, reason: ShapeSkipReason.pathGenerationFailed));
        continue;
      }
      
      // Track if the shape was auto-closed (for user feedback)
      if (forceClose && result.wasAutoClosed) {
        skippedShapes.add(SkippedShape(id: shape.id, reason: ShapeSkipReason.autoClosed));
      }
      
      paths.add(result.path);
      mergedSourceIds.add(shape.id);
      usedStrokeOutline = usedStrokeOutline || result.usedStrokeOutline;
    }

    if (mergedSourceIds.length < 2 || paths.isEmpty) {
      return MergeResult(
        mergedShapes: const [],
        removedIds: const [],
        skippedShapes: skippedShapes,
      );
    }

    var mergedPath = paths.first;
    final pathOperation = mode.pathOperation;
    for (var i = 1; i < paths.length; i++) {
      mergedPath = Path.combine(pathOperation, mergedPath, paths[i]);
    }

    // Calculate adaptive sample distance based on merged path size
    // Use finer sampling for curved shapes to preserve smooth curves
    var effectiveSampleDistance = sampleDistance > 0
        ? sampleDistance
        : _adaptiveSampleDistance(mergedPath);

    // For shapes with Bezier curves, use much finer sampling to preserve curve detail
    if (hasCurvedShapes && sampleDistance <= 0) {
      effectiveSampleDistance = math.min(effectiveSampleDistance, 1.0);
    }

    final rawContours = _contoursFromPath(
      mergedPath,
      sampleDistance: effectiveSampleDistance,
      allowAdaptiveForShortContours: sampleDistance <= 0,
    );
    if (rawContours.isEmpty) {
      return MergeResult(
        mergedShapes: const [],
        removedIds: const [],
        skippedShapes: skippedShapes,
      );
    }

    // Apply path simplification to reduce point count
    // Use a lower epsilon for curved shapes to preserve curve detail
    // For curved shapes: 0.25 preserves smooth curves well
    // For non-curved shapes: 0.5-0.75 is sufficient
    final baseEpsilon = simplifyEpsilon > 0 ? simplifyEpsilon.clamp(0.0, 0.75) : 0.5;
    final effectiveEpsilon = hasCurvedShapes ? math.min(baseEpsilon, 0.25) : baseEpsilon;
    final simplifiedContours = rawContours
        .map((contour) {
          final simplified = _simplifier.simplify(contour, effectiveEpsilon);
          return _removeNearDuplicatePoints(simplified);
        })
        .where((contour) => contour.length >= 3)
        .toList(growable: false);

    final Color strokeColor = styleSource.strokeColor;
    final double strokeWidth = styleSource.strokeWidth;
    // Only inherit fill color from style source - don't auto-apply stroke color as fill.
    // The previous logic `usedStrokeOutline ? strokeColor : null` caused unexpected black fills
    // when merging non-closed freehand shapes.
    final Color? fillColor = styleSource.fillColor;

    final mergedContours =
        simplifiedContours.where((contour) => contour.length >= 3).toList(growable: false);
    if (mergedContours.isEmpty) {
      return MergeResult(
        mergedShapes: const [],
        removedIds: const [],
        skippedShapes: skippedShapes,
      );
    }

    // Fit bezier curves to the merged contours for smooth rendering
    // This preserves smooth curves for curved sections and creates corner nodes for sharp angles
    //
    // Important: Pass tolerance: 0 to skip RDP simplification inside fitBezierCurves since
    // the contours are already simplified. Double simplification over-reduces circles to 4 points.
    //
    // Corner threshold determines when a point becomes a sharp corner vs smooth curve:
    // - For curved shapes: use 30° (pi/6) - only very sharp angles become corners
    // - For non-curved shapes: use 45° (pi/4) - more generous corner detection
    // This preserves smooth curves on merged bezier paths while still detecting true corners.
    final cornerThreshold = hasCurvedShapes ? math.pi / 6 : math.pi / 4;
    final rawBezierPoints = mergedContours.first.length >= 3
        ? PathSimplification.fitBezierCurves(
            mergedContours.first,
            tolerance: 0, // Skip internal simplification - already simplified
            cornerAngleThreshold: cornerThreshold,
          )
        : null;

    // CRITICAL: bezierPoints must have the same length as points for node editing to work.
    // If they don't match, node operations will update points but not all bezierPoints,
    // causing the rendered shape (using bezierPoints) to desync from the node overlay (using points).
    final bezierPoints = (rawBezierPoints != null &&
                          rawBezierPoints.length == mergedContours.first.length)
        ? rawBezierPoints
        : null;

    final mergedShape = Shape(
      id: createId(),
      kind: ShapeKind.polygon,
      points: mergedContours.first,
      contours: mergedContours.length > 1 ? mergedContours : null,
      bezierPoints: bezierPoints,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillColor: fillColor,
      opacity: styleSource.opacity,
      brushType: styleSource.brushType,
      isClosed: true,
      // Inherit visibility and lock state from the style source shape
      isVisible: styleSource.isVisible,
      isLocked: styleSource.isLocked,
    );

    return MergeResult(
      mergedShapes: [mergedShape],
      removedIds: mergedSourceIds,
      skippedShapes: skippedShapes,
    );
  }

  Shape _findStyleSource(
    List<String> selectedIds,
    List<Shape> shapes,
    List<Shape> selectedShapes,
  ) {
    final firstId = selectedIds.first;
    for (final shape in shapes) {
      if (shape.id == firstId) return shape;
    }
    return selectedShapes.first;
  }

  _PathResult? _pathForShape({
    required Shape shape,
    required bool strokeScaleWithShape,
    required double brushSmoothness,
    bool forceClose = false,
  }) {
    switch (shape.kind) {
      case ShapeKind.freehand:
        return _pathForFreehand(
          shape,
          strokeScaleWithShape: strokeScaleWithShape,
          brushSmoothness: brushSmoothness,
          forceClose: forceClose,
        );
      case ShapeKind.line:
        return _pathForLine(
          shape,
          strokeScaleWithShape: strokeScaleWithShape,
          brushSmoothness: brushSmoothness,
          forceClose: forceClose,
        );
      case ShapeKind.rectangle:
        return _pathForBounds(shape, addRect: true);
      case ShapeKind.ellipse:
        return _pathForBounds(shape, addRect: false);
      case ShapeKind.polygon:
      case ShapeKind.pointPath:
        return _pathForPolygon(shape);
      case ShapeKind.image:
        return null; // Images cannot be merged
    }
  }

  _PathResult? _pathForFreehand(
    Shape shape, {
    required bool strokeScaleWithShape,
    required double brushSmoothness,
    bool forceClose = false,
  }) {
    if (shape.points.length < 2) return null;
    final base = shape.localBounds;
    if (base == null) return null;
    
    final isClosed = _isFreehandClosed(shape);
    
    // If shape is closed or we're forcing closed (for intersect/difference modes),
    // treat it as a filled polygon path
    if (isClosed || forceClose) {
      final path = _multiContourPath([shape.points]);
      final matrix = shape.matrixForRect(base);
      // Track if we auto-closed for user feedback
      final wasAutoClosed = !isClosed && forceClose;
      return _PathResult(_transformPath(path, matrix), false, wasAutoClosed: wasAutoClosed);
    }
    
    // For non-closed shapes in union mode, convert to stroke outline
    final matrix = shape.matrixForRect(base);
    final worldPoints = _transformOffsets(shape.points, matrix);
    final strokeWidth =
        _effectiveStrokeWidth(shape, strokeScaleWithShape);
    final path = _strokeOutlinePath(
      worldPoints,
      strokeWidth,
      brushSmoothness,
      pressures: shape.pointPressures,
    );
    if (path == null) return null;
    return _PathResult(path, true);
  }

  _PathResult? _pathForLine(
    Shape shape, {
    required bool strokeScaleWithShape,
    required double brushSmoothness,
    bool forceClose = false,
  }) {
    if (shape.points.length < 2) return null;
    final base = shape.localBounds;
    if (base == null) return null;
    final matrix = shape.matrixForRect(base);
    
    // For forceClose (intersect/difference modes), treat line as a closed polygon
    if (forceClose && shape.points.length >= 3) {
      final path = _multiContourPath([shape.points]);
      return _PathResult(_transformPath(path, matrix), false, wasAutoClosed: true);
    }
    
    // For union mode or lines with < 3 points, convert to stroke outline
    final worldPoints = _transformOffsets(shape.points, matrix);
    final strokeWidth =
        _effectiveStrokeWidth(shape, strokeScaleWithShape);
    final path = _strokeOutlinePath(
      worldPoints,
      strokeWidth,
      brushSmoothness,
      pressures: shape.pointPressures,
    );
    if (path == null) return null;
    return _PathResult(path, true);
  }

  _PathResult? _pathForBounds(Shape shape, {required bool addRect}) {
    final rect = shape.bounds;
    if (rect == null) return null;
    Path path;
    if (addRect) {
      path = Path()..addRect(rect);
    } else {
      path = Path()..addOval(rect);
    }
    final matrix = shape.matrixForRect(rect);
    return _PathResult(_transformPath(path, matrix), false);
  }

  _PathResult? _pathForPolygon(Shape shape) {
    final base = shape.localBounds;
    if (base == null) return null;
    final matrix = shape.matrixForRect(base);

    // If shape has Bezier curves, use them for accurate path generation
    if (shape.hasBezierCurves && shape.bezierPoints!.isNotEmpty) {
      final path = _bezierPath(shape.bezierPoints!, shape.isClosed);
      return _PathResult(_transformPath(path, matrix), false);
    }

    // Fallback to line-based contours
    final contours = shape.contours.isNotEmpty
        ? shape.contours
        : (shape.points.isNotEmpty ? [shape.points] : const <List<Offset>>[]);
    if (contours.isEmpty) return null;
    final path = _multiContourPath(contours);
    return _PathResult(_transformPath(path, matrix), false);
  }

  /// Creates a path from Bezier points with proper cubic curves.
  Path _bezierPath(List<BezierPoint> bezierPoints, bool isClosed) {
    if (bezierPoints.isEmpty) return Path();

    final path = Path();
    path.moveTo(bezierPoints.first.position.dx, bezierPoints.first.position.dy);

    for (var i = 1; i < bezierPoints.length; i++) {
      final prev = bezierPoints[i - 1];
      final curr = bezierPoints[i];

      // Get control points
      final cp1 = prev.controlOutAbsolute;
      final cp2 = curr.controlInAbsolute;

      // Use cubic bezier if we have control handles, otherwise line
      if (prev.controlOut != null || curr.controlIn != null) {
        path.cubicTo(
          cp1.dx, cp1.dy,
          cp2.dx, cp2.dy,
          curr.position.dx, curr.position.dy,
        );
      } else {
        path.lineTo(curr.position.dx, curr.position.dy);
      }
    }

    // Close the path if needed
    if (isClosed && bezierPoints.length > 2) {
      final last = bezierPoints.last;
      final first = bezierPoints.first;

      final cp1 = last.controlOutAbsolute;
      final cp2 = first.controlInAbsolute;

      if (last.controlOut != null || first.controlIn != null) {
        path.cubicTo(
          cp1.dx, cp1.dy,
          cp2.dx, cp2.dy,
          first.position.dx, first.position.dy,
        );
      }
      path.close();
    }

    return path;
  }

  Path _multiContourPath(List<List<Offset>> contours) {
    final path = Path();
    for (final points in contours) {
      if (points.isEmpty) continue;
      path.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p = points[i];
        path.lineTo(p.dx, p.dy);
      }
      if (points.length > 2) {
        path.close();
      }
    }
    if (contours.length > 1) {
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  List<Offset> _transformOffsets(List<Offset> points, Matrix4 matrix) {
    return points
        .map((p) => _transformOffset(matrix, p))
        .toList(growable: false);
  }

  Offset _transformOffset(Matrix4 matrix, Offset point) {
    final v = matrix.transform3(Vector3(point.dx, point.dy, 0));
    return Offset(v.x, v.y);
  }

  Path _transformPath(Path path, Matrix4 matrix) {
    return path.transform(matrix.storage);
  }

  double _effectiveStrokeWidth(Shape shape, bool strokeScaleWithShape) {
    final scale = _strokeScaleFor(shape);
    final scaleFactor = strokeScaleWithShape ? math.max(1.0, scale) : 1.0;
    return shape.strokeWidth / scaleFactor;
  }

  double _strokeScaleFor(Shape shape) {
    final sx = shape.scaleX.abs();
    final sy = shape.scaleY.abs();
    final maxScale = sx > sy ? sx : sy;
    return maxScale <= 0.0001 ? 1.0 : maxScale;
  }

  bool _isFreehandClosed(Shape shape) {
    if (shape.isClosed) return true;
    return _isClosedPoints(shape.points);
  }

  bool _isClosedPoints(List<Offset> points, {double threshold = 6.0}) {
    if (points.length < 3) return false;
    final first = points.first;
    final last = points.last;
    return (first - last).distance <= threshold;
  }

  Path? _strokeOutlinePath(
    List<Offset> points,
    double strokeWidth,
    double brushSmoothness, {
    List<double>? pressures,
  }) {
    if (points.isEmpty || strokeWidth <= 0) return null;
    final hasPressure = pressures != null && pressures.length == points.length;
    final vectors = hasPressure
        ? List<PointVector>.generate(
            points.length,
            (i) => PointVector.fromOffset(
              offset: points[i],
              pressure: pressures![i],
            ),
            growable: false,
          )
        : points
            .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
            .toList(growable: false);
    final outline = getStroke(
      vectors,
      options: StrokeOptions(
        size: strokeWidth,
        thinning: 0.5,
        smoothing: _strokeSmoothing(brushSmoothness),
        streamline: _strokeStreamline(brushSmoothness),
        simulatePressure: true,
        isComplete: true,
      ),
    );
    return _outlineToPath(outline);
  }

  double _strokeSmoothing(double slider) =>
      StrokeRenderConfig.smoothingForValue(slider.clamp(0.0, 1.0));

  double _strokeStreamline(double slider) =>
      StrokeRenderConfig.streamlineForValue(slider.clamp(0.0, 1.0));

  Path? _outlineToPath(List<Offset> outline) {
    if (outline.isEmpty) return null;
    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      final pt = outline[i];
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  List<List<Offset>> _contoursFromPath(
    Path path, {
    required double sampleDistance,
    bool allowAdaptiveForShortContours = false,
  }) {
    final contours = <List<Offset>>[];
    for (final metric in path.computeMetrics()) {
      if (metric.length <= 0) continue;
      final adaptive = _adaptiveSampleDistanceForMetric(metric.length);
      final baseDistance = sampleDistance <= 0 ? defaultSampleDistance : sampleDistance;
      final distance = allowAdaptiveForShortContours
          ? math.min(baseDistance, adaptive)
          : baseDistance;
      final step = distance.clamp(minSampleDistance, maxSampleDistance);
      final points = <Offset>[];
      var d = 0.0;
      while (d < metric.length) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) points.add(tangent.position);
        d += step;
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null) points.add(end.position);
      final cleaned = _dedupePoints(points, epsilon: step * 0.3);
      if (cleaned.length >= 3) {
        contours.add(cleaned);
      }
    }
    return contours;
  }

  double _adaptiveSampleDistanceForMetric(double length) {
    if (length <= 0) return defaultSampleDistance;
    const targetSamplesPerLength = 750.0;
    final adaptiveDistance = length / targetSamplesPerLength;
    return adaptiveDistance.clamp(minSampleDistance, maxSampleDistance);
  }

  List<Offset> _removeNearDuplicatePoints(List<Offset> points) {
    if (points.length < 3) return points;
    final minDistance = _minPointSeparation(points);
    if (minDistance <= 0) return points;
    return _dedupePoints(points, epsilon: minDistance);
  }

  double _minPointSeparation(List<Offset> points) {
    if (points.length < 2) return 0.0;
    final avg = _averageSegmentLength(points);
    return math.max(0.5, avg * 0.15);
  }

  double _averageSegmentLength(List<Offset> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total / (points.length - 1);
  }

  List<Offset> _dedupePoints(
    List<Offset> points, {
    required double epsilon,
  }) {
    if (points.length < 2) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - result.last).distance >= epsilon) {
        result.add(points[i]);
      }
    }
    // Remove last point if it's too close to the first (closed path duplicate)
    if (result.length > 2 &&
        (result.first - result.last).distance < epsilon) {
      result.removeLast();
    }
    return result;
  }

}

/// Information about a shape that was skipped during merge.
class SkippedShape {
  const SkippedShape({
    required this.id,
    required this.reason,
  });

  final String id;
  final ShapeSkipReason reason;
}

class MergeResult {
  const MergeResult({
    required this.mergedShapes,
    required this.removedIds,
    required this.skippedShapes,
  });

  const MergeResult.empty()
      : mergedShapes = const [],
        removedIds = const [],
        skippedShapes = const [];

  final List<Shape> mergedShapes;
  final List<String> removedIds;
  final List<SkippedShape> skippedShapes;

  /// Legacy getter for backward compatibility.
  List<String> get skippedIds => skippedShapes.map((s) => s.id).toList();
  
  /// Returns true if any shapes were skipped.
  bool get hasSkippedShapes => skippedShapes.isNotEmpty;
  
  /// Gets a summary of skip reasons for user feedback.
  String get skipSummary {
    if (skippedShapes.isEmpty) return '';
    
    final reasonCounts = <ShapeSkipReason, int>{};
    for (final skipped in skippedShapes) {
      reasonCounts[skipped.reason] = (reasonCounts[skipped.reason] ?? 0) + 1;
    }
    
    final parts = <String>[];
    for (final entry in reasonCounts.entries) {
      parts.add('${entry.value} ${_reasonDescription(entry.key)}');
    }
    return parts.join(', ');
  }
  
  String _reasonDescription(ShapeSkipReason reason) {
    switch (reason) {
      case ShapeSkipReason.noPoints:
        return 'empty';
      case ShapeSkipReason.tooFewPoints:
        return 'too few points';
      case ShapeSkipReason.invalidCoordinates:
        return 'invalid coordinates';
      case ShapeSkipReason.zeroArea:
        return 'zero area';
      case ShapeSkipReason.tooSmall:
        return 'too small';
      case ShapeSkipReason.noBounds:
        return 'no bounds';
      case ShapeSkipReason.pathGenerationFailed:
        return 'path failed';
      case ShapeSkipReason.autoClosed:
        return 'auto-closed';
    }
  }
}

class _PathResult {
  const _PathResult(this.path, this.usedStrokeOutline, {this.wasAutoClosed = false});

  final Path path;
  final bool usedStrokeOutline;
  /// Whether the shape was auto-closed for the merge operation (for user feedback).
  final bool wasAutoClosed;
}

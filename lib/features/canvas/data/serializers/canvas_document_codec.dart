import 'dart:convert';
import 'dart:ui';

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/features/canvas/domain/entities/audio_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class CanvasDocumentCodec {
  static String encode(CanvasDocument document) {
    return jsonEncode(toJson(document));
  }

  static CanvasDocument decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid document JSON');
    }
    return fromJson(decoded);
  }

  static Map<String, dynamic> toJson(CanvasDocument document) {
    return {
      'version': document.version,
      'id': document.id,
      'title': document.title,
      'size': _sizeToJson(document.size),
      'background': _backgroundToJson(document.background),
      'fps': document.fps,
      'frameCount': document.frameCount,
      'sceneCameraTimeline': document.sceneCameraTimeline.toJson(),
      'objectTimeline': document.objectTimeline.toJson(),
      'createdAt': document.createdAt.toIso8601String(),
      'updatedAt': document.updatedAt.toIso8601String(),
      'layers': document.layers.map(_layerToJson).toList(growable: false),
      'audioTracks': document.audioTracks
          .map(_audioTrackToJson)
          .toList(growable: false),
      'recentColors': document.recentColors.toList(growable: false),
    };
  }

  static CanvasDocument fromJson(Map<String, dynamic> json) {
    final size = _sizeFromJson(json['size']);
    final background = _backgroundFromJson(json['background']);
    final fps = _num(json['fps'], kDefaultFps);
    var frameCount = _int(json['frameCount'], kDefaultFrameCount);
    final layersRaw = json['layers'];
    final layers = <CanvasLayer>[];
    if (layersRaw is List) {
      for (final entry in layersRaw) {
        if (entry is Map<String, dynamic>) {
          layers.add(_layerFromJson(entry));
        }
      }
    }
    final audioRaw = json['audioTracks'];
    final audio = <AudioTrack>[];
    if (audioRaw is List) {
      for (final entry in audioRaw) {
        if (entry is Map<String, dynamic>) {
          audio.add(_audioTrackFromJson(entry));
        }
      }
    }
    final createdAt = _dateTime(json['createdAt']);
    final updatedAt = _dateTime(json['updatedAt']);
    final recentColors = _intList(json['recentColors']);
    final sceneCameraTimeline = SceneCameraTimeline.fromJson(
      json['sceneCameraTimeline'],
    );
    final objectTimeline = ObjectTimeline.fromJson(json['objectTimeline']);

    if (layers.isEmpty) {
      layers.add(
        CanvasLayer(
          id: 'layer-1',
          name: 'Layer 1',
          frames: {0: CanvasFrame(index: 0)},
        ),
      );
    }

    final maxIndex = _maxFrameIndex(layers);
    if (maxIndex >= 0 && frameCount <= maxIndex) {
      frameCount = maxIndex + 1;
    }

    return CanvasDocument(
      id: (json['id'] as String?) ?? 'document-1',
      title: (json['title'] as String?) ?? 'Untitled',
      size: size,
      background: background,
      fps: fps,
      frameCount: frameCount,
      layers: layers,
      sceneCameraTimeline: sceneCameraTimeline,
      objectTimeline: objectTimeline,
      audioTracks: audio,
      recentColors: recentColors,
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: _int(json['version'], 1),
    );
  }

  static Map<String, dynamic> _layerToJson(CanvasLayer layer) {
    final frames = layer.frames.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return {
      'id': layer.id,
      'name': layer.name,
      'visible': layer.isVisible,
      'locked': layer.isLocked,
      'opacity': layer.opacity,
      'blendMode': layer.blendMode.name,
      'frames': frames.map(_frameToJson).toList(growable: false),
    };
  }

  static CanvasLayer _layerFromJson(Map<String, dynamic> json) {
    final framesRaw = json['frames'];
    final frames = <int, CanvasFrame>{};
    if (framesRaw is List) {
      for (final entry in framesRaw) {
        if (entry is Map<String, dynamic>) {
          final frame = _frameFromJson(entry);
          frames[frame.index] = frame;
        }
      }
    }
    if (frames.isEmpty) {
      frames[0] = CanvasFrame(index: 0);
    }
    return CanvasLayer(
      id: (json['id'] as String?) ?? 'layer-1',
      name: (json['name'] as String?) ?? 'Layer 1',
      isVisible: json['visible'] as bool? ?? true,
      isLocked: json['locked'] as bool? ?? false,
      opacity: _num(json['opacity'], 1.0),
      blendMode: _blendMode(json['blendMode']),
      frames: frames,
    );
  }

  static Map<String, dynamic> _frameToJson(CanvasFrame frame) {
    return {
      'index': frame.index,
      'shapes': frame.shapes.map(_shapeToJson).toList(growable: false),
    };
  }

  static CanvasFrame _frameFromJson(Map<String, dynamic> json) {
    final shapesRaw = json['shapes'];
    final shapes = <Shape>[];
    if (shapesRaw is List) {
      for (final entry in shapesRaw) {
        if (entry is Map<String, dynamic>) {
          shapes.add(_shapeFromJson(entry));
        }
      }
    }
    return CanvasFrame(index: _int(json['index'], 0), shapes: shapes);
  }

  static Map<String, dynamic> _shapeToJson(Shape shape) {
    return {
      'id': shape.id,
      'kind': shape.kind.name,
      'name': shape.name,
      'metadata': shape.metadata,
      'points': shape.points.map((p) => [p.dx, p.dy]).toList(growable: false),
      'pointPressures': shape.pointPressures?.toList(growable: false),
      'contours': shape.contours.isNotEmpty
          ? shape.contours
                .map(
                  (contour) =>
                      contour.map((p) => [p.dx, p.dy]).toList(growable: false),
                )
                .toList(growable: false)
          : null,
      'eraseContours':
          shape.eraseContours != null && shape.eraseContours!.isNotEmpty
          ? shape.eraseContours!
                .map(
                  (contour) =>
                      contour.map((p) => [p.dx, p.dy]).toList(growable: false),
                )
                .toList(growable: false)
          : null,
      'bezierPoints': shape.bezierPoints != null
          ? shape.bezierPoints!
                .map((bp) => _bezierPointToJson(bp))
                .toList(growable: false)
          : null,
      'bounds': shape.bounds != null ? _rectToJson(shape.bounds!) : null,
      'strokeColor': shape.strokeColor.value,
      'strokeWidth': shape.strokeWidth,
      'fillColor': shape.fillColor?.value,
      'opacity': shape.opacity,
      'isVisible': shape.isVisible,
      'isLocked': shape.isLocked,
      'brushType': shape.brushType?.name,
      'brushSmoothness': shape.brushSmoothness,
      'isClosed': shape.isClosed,
      'groupId': shape.groupId,
      'parentId': shape.parentId,
      'spatialObjectId': shape.spatialObjectId,
      'isFlippedH': shape.isFlippedH,
      'isFlippedV': shape.isFlippedV,
      'imagePath': shape.imagePath,
      'imageOriginalSize': shape.imageOriginalSize != null
          ? {
              'width': shape.imageOriginalSize!.width,
              'height': shape.imageOriginalSize!.height,
            }
          : null,
      'transform': {
        'position': _offsetToJson(shape.translation),
        'rotation': shape.rotation,
        'scaleX': shape.scaleX,
        'scaleY': shape.scaleY,
        'pivot': _offsetToJson(shape.transform.pivot),
      },
    };
  }

  static Shape _shapeFromJson(Map<String, dynamic> json) {
    final kind = _shapeKind(json['kind']);
    final pointsRaw = json['points'];
    final points = <Offset>[];
    if (pointsRaw is List) {
      for (final entry in pointsRaw) {
        if (entry is List && entry.length >= 2) {
          points.add(Offset(_num(entry[0], 0.0), _num(entry[1], 0.0)));
        }
      }
    }
    final contoursRaw = json['contours'];
    final contours = <List<Offset>>[];
    if (contoursRaw is List) {
      for (final contourEntry in contoursRaw) {
        if (contourEntry is List) {
          final contour = <Offset>[];
          for (final entry in contourEntry) {
            if (entry is List && entry.length >= 2) {
              contour.add(Offset(_num(entry[0], 0.0), _num(entry[1], 0.0)));
            }
          }
          if (contour.isNotEmpty) {
            contours.add(List<Offset>.unmodifiable(contour));
          }
        }
      }
    }
    final bounds = _rectFromJson(json['bounds']);
    final pressuresRaw = json['pointPressures'];
    final pressures = pressuresRaw is List
        ? List<double>.unmodifiable(pressuresRaw.map((p) => _num(p, 1.0)))
        : null;
    final bezierPointsRaw = json['bezierPoints'];
    final bezierPoints = bezierPointsRaw is List
        ? bezierPointsRaw
              .map((bp) => _bezierPointFromJson(bp))
              .whereType<BezierPoint>()
              .toList(growable: false)
        : null;
    final transformJson = json['transform'];
    final transform = _transformFromJson(transformJson);
    final resolvedPoints = points.isNotEmpty || contours.isEmpty
        ? points
        : contours.first;
    final eraseContoursRaw = json['eraseContours'];
    final eraseContours = <List<Offset>>[];
    if (eraseContoursRaw is List) {
      for (final contourEntry in eraseContoursRaw) {
        if (contourEntry is List) {
          final contour = <Offset>[];
          for (final entry in contourEntry) {
            if (entry is List && entry.length >= 2) {
              contour.add(Offset(_num(entry[0], 0.0), _num(entry[1], 0.0)));
            }
          }
          if (contour.isNotEmpty) {
            eraseContours.add(List<Offset>.unmodifiable(contour));
          }
        }
      }
    }
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : null;
    return Shape(
      id: (json['id'] as String?) ?? 'shape',
      kind: kind,
      name: json['name'] as String?,
      metadata: metadata,
      points: resolvedPoints,
      pointPressures: pressures,
      contours: contours,
      bezierPoints: bezierPoints != null && bezierPoints.isNotEmpty
          ? bezierPoints
          : null,
      bounds: bounds,
      strokeColor: _color(json['strokeColor'], const Color(0xFF000000)),
      strokeWidth: _num(json['strokeWidth'], 2.0),
      fillColor: _colorNullable(json['fillColor']),
      opacity: _num(json['opacity'], 1.0),
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      transform: transform,
      brushType: _brushType(json['brushType']),
      brushSmoothness: (json['brushSmoothness'] as num?)?.toDouble(),
      isClosed: json['isClosed'] as bool? ?? false,
      groupId: json['groupId'] as String?,
      parentId: json['parentId'] as String?,
      spatialObjectId: json['spatialObjectId'] as String?,
      isFlippedH: json['isFlippedH'] as bool? ?? false,
      isFlippedV: json['isFlippedV'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      imageOriginalSize: _sizeNullableFromJson(json['imageOriginalSize']),
      eraseContours: eraseContours.isNotEmpty ? eraseContours : null,
    );
  }

  static Map<String, dynamic> _audioTrackToJson(AudioTrack track) {
    return {
      'id': track.id,
      'name': track.name,
      'source': track.source,
      'offsetMs': track.offsetMs,
      'gain': track.gain,
      'muted': track.isMuted,
      'markers': track.markers
          .map(
            (m) => {'timeMs': m.timeMs, 'label': m.label, 'kind': m.kind.name},
          )
          .toList(growable: false),
    };
  }

  static AudioTrack _audioTrackFromJson(Map<String, dynamic> json) {
    final markersRaw = json['markers'];
    final markers = <AudioMarker>[];
    if (markersRaw is List) {
      for (final entry in markersRaw) {
        if (entry is Map<String, dynamic>) {
          markers.add(
            AudioMarker(
              timeMs: _int(entry['timeMs'], 0),
              label: (entry['label'] as String?) ?? '',
              kind: _audioMarkerKind(entry['kind']),
            ),
          );
        }
      }
    }
    return AudioTrack(
      id: (json['id'] as String?) ?? 'audio-1',
      name: (json['name'] as String?) ?? 'Audio',
      source: (json['source'] as String?) ?? '',
      offsetMs: _int(json['offsetMs'], 0),
      gain: _num(json['gain'], 1.0),
      isMuted: json['muted'] as bool? ?? false,
      markers: List<AudioMarker>.unmodifiable(markers),
    );
  }

  static Map<String, dynamic> _offsetToJson(Offset offset) {
    return {'dx': offset.dx, 'dy': offset.dy};
  }

  static Offset _offsetFromJson(
    dynamic value, {
    Offset fallback = Offset.zero,
  }) {
    if (value is Map<String, dynamic>) {
      return Offset(
        _num(value['dx'], fallback.dx),
        _num(value['dy'], fallback.dy),
      );
    }
    return fallback;
  }

  static Map<String, dynamic> _bezierPointToJson(BezierPoint bp) {
    return {
      'position': _offsetToJson(bp.position),
      if (bp.controlIn != null) 'controlIn': _offsetToJson(bp.controlIn!),
      if (bp.controlOut != null) 'controlOut': _offsetToJson(bp.controlOut!),
    };
  }

  static BezierPoint? _bezierPointFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final position = _offsetFromJson(value['position']);
    final controlIn = value['controlIn'] != null
        ? _offsetFromJson(value['controlIn'])
        : null;
    final controlOut = value['controlOut'] != null
        ? _offsetFromJson(value['controlOut'])
        : null;
    return BezierPoint(
      position: position,
      controlIn: controlIn,
      controlOut: controlOut,
    );
  }

  static Map<String, dynamic> _rectToJson(Rect rect) {
    return {
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }

  static Rect? _rectFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (value.containsKey('width') && value.containsKey('height')) {
        return Rect.fromLTWH(
          _num(value['left'], 0.0),
          _num(value['top'], 0.0),
          _num(value['width'], 0.0),
          _num(value['height'], 0.0),
        );
      }
      if (value.containsKey('right') && value.containsKey('bottom')) {
        return Rect.fromLTRB(
          _num(value['left'], 0.0),
          _num(value['top'], 0.0),
          _num(value['right'], 0.0),
          _num(value['bottom'], 0.0),
        );
      }
    }
    return null;
  }

  static Map<String, dynamic> _sizeToJson(Size size) {
    return {'width': size.width, 'height': size.height};
  }

  static Size _sizeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Size(
        _num(value['width'], kDefaultCanvasSize.width),
        _num(value['height'], kDefaultCanvasSize.height),
      );
    }
    return kDefaultCanvasSize;
  }

  static Size? _sizeNullableFromJson(dynamic value) {
    if (value is Map<String, dynamic> &&
        value.containsKey('width') &&
        value.containsKey('height')) {
      return Size(_num(value['width'], 0), _num(value['height'], 0));
    }
    return null;
  }

  static Map<String, dynamic> _backgroundToJson(CanvasBackground background) {
    return {
      'kind': background.kind.name,
      'color': background.color?.value,
      'imagePath': background.imagePath,
    };
  }

  static CanvasBackground _backgroundFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      final kindValue = value['kind'];
      CanvasBackgroundKind kind = CanvasBackgroundKind.solid;
      if (kindValue is String) {
        for (final entry in CanvasBackgroundKind.values) {
          if (entry.name == kindValue) {
            kind = entry;
            break;
          }
        }
      }
      final color = _colorNullable(value['color']);
      final imagePath = value['imagePath'] as String?;
      switch (kind) {
        case CanvasBackgroundKind.transparent:
          return const CanvasBackground.transparent();
        case CanvasBackgroundKind.image:
          if (imagePath != null && imagePath.isNotEmpty) {
            return CanvasBackground.image(
              imagePath,
              fallbackColor: color ?? kDefaultCanvasBackgroundColor,
            );
          }
          return CanvasBackground.solid(color ?? kDefaultCanvasBackgroundColor);
        case CanvasBackgroundKind.solid:
          return CanvasBackground.solid(color ?? kDefaultCanvasBackgroundColor);
      }
    }
    return const CanvasBackground.transparent();
  }

  static Transform2D _transformFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Transform2D(
        position: _offsetFromJson(value['position']),
        rotation: _num(value['rotation'], 0.0),
        scaleX: _num(value['scaleX'], 1.0),
        scaleY: _num(value['scaleY'], 1.0),
        pivot: _offsetFromJson(value['pivot']),
      );
    }
    return const Transform2D();
  }

  static Color _color(dynamic value, Color fallback) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    if (value is String) {
      var cleaned = value.replaceAll('#', '');
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned';
      }
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }
    return fallback;
  }

  static Color? _colorNullable(dynamic value) {
    if (value == null) return null;
    return _color(value, const Color(0xFF000000));
  }

  static BrushType? _brushType(dynamic value) {
    if (value is String) {
      for (final type in BrushType.values) {
        if (type.name == value) return type;
      }
    }
    if (value is int && value >= 0 && value < BrushType.values.length) {
      return BrushType.values[value];
    }
    return null;
  }

  static ShapeKind _shapeKind(dynamic value) {
    if (value is String) {
      for (final kind in ShapeKind.values) {
        if (kind.name == value) return kind;
      }
    }
    if (value is int && value >= 0 && value < ShapeKind.values.length) {
      return ShapeKind.values[value];
    }
    return ShapeKind.rectangle;
  }

  static AudioMarkerKind _audioMarkerKind(dynamic value) {
    if (value is String) {
      for (final kind in AudioMarkerKind.values) {
        if (kind.name == value) return kind;
      }
    }
    if (value is int && value >= 0 && value < AudioMarkerKind.values.length) {
      return AudioMarkerKind.values[value];
    }
    return AudioMarkerKind.marker;
  }

  static BlendMode _blendMode(dynamic value) {
    if (value is String) {
      for (final mode in BlendMode.values) {
        if (mode.name == value) return mode;
      }
    }
    if (value is int && value >= 0 && value < BlendMode.values.length) {
      return BlendMode.values[value];
    }
    return BlendMode.srcOver;
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double _num(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  static List<int> _intList(dynamic value) {
    if (value is! List) return const <int>[];
    final result = <int>[];
    for (final entry in value) {
      if (entry is int) {
        result.add(entry);
      } else if (entry is num) {
        result.add(entry.toInt());
      }
    }
    return List<int>.unmodifiable(result);
  }

  static int _maxFrameIndex(List<CanvasLayer> layers) {
    var maxIndex = -1;
    for (final layer in layers) {
      for (final frame in layer.frames.values) {
        if (frame.index > maxIndex) {
          maxIndex = frame.index;
        }
      }
    }
    return maxIndex;
  }
}

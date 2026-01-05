import 'dart:convert';
import 'dart:ui';

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/features/canvas/domain/entities/audio_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/raster_stroke.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

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
      'fps': document.fps,
      'frameCount': document.frameCount,
      'createdAt': document.createdAt.toIso8601String(),
      'updatedAt': document.updatedAt.toIso8601String(),
      'layers': document.layers
          .map(_layerToJson)
          .toList(growable: false),
      'audioTracks': document.audioTracks
          .map(_audioTrackToJson)
          .toList(growable: false),
    };
  }

  static CanvasDocument fromJson(Map<String, dynamic> json) {
    final size = _sizeFromJson(json['size']);
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
      fps: fps,
      frameCount: frameCount,
      layers: layers,
      audioTracks: audio,
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
      'rasterStrokes': frame.rasterStrokes
          .map(_rasterStrokeToJson)
          .toList(growable: false),
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
    final strokesRaw = json['rasterStrokes'];
    final strokes = <RasterStroke>[];
    if (strokesRaw is List) {
      for (final entry in strokesRaw) {
        if (entry is Map<String, dynamic>) {
          strokes.add(_rasterStrokeFromJson(entry));
        }
      }
    }
    return CanvasFrame(
      index: _int(json['index'], 0),
      shapes: shapes,
      rasterStrokes: strokes,
    );
  }

  static Map<String, dynamic> _shapeToJson(Shape shape) {
    return {
      'id': shape.id,
      'kind': shape.kind.name,
      'points': shape.points
          .map((p) => [p.dx, p.dy])
          .toList(growable: false),
      'bounds': shape.bounds != null ? _rectToJson(shape.bounds!) : null,
      'strokeColor': shape.strokeColor.value,
      'strokeWidth': shape.strokeWidth,
      'fillColor': shape.fillColor?.value,
      'opacity': shape.opacity,
      'brushType': shape.brushType?.name,
      'isClosed': shape.isClosed,
      'groupId': shape.groupId,
      'isFlippedH': shape.isFlippedH,
      'isFlippedV': shape.isFlippedV,
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
    final bounds = _rectFromJson(json['bounds']);
    final transformJson = json['transform'];
    final transform = _transformFromJson(transformJson);
    return Shape(
      id: (json['id'] as String?) ?? 'shape',
      kind: kind,
      points: points,
      bounds: bounds,
      strokeColor: _color(json['strokeColor'], const Color(0xFF000000)),
      strokeWidth: _num(json['strokeWidth'], 2.0),
      fillColor: _colorNullable(json['fillColor']),
      opacity: _num(json['opacity'], 1.0),
      transform: transform,
      brushType: _brushType(json['brushType']),
      isClosed: json['isClosed'] as bool? ?? false,
      groupId: json['groupId'] as String?,
      isFlippedH: json['isFlippedH'] as bool? ?? false,
      isFlippedV: json['isFlippedV'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _rasterStrokeToJson(RasterStroke stroke) {
    return {
      'points': stroke.points
          .map(
            (p) => [p.x, p.y, p.pressure ?? 1.0],
          )
          .toList(growable: false),
      'color': stroke.color.value,
      'strokeWidth': stroke.strokeWidth,
      'opacity': stroke.opacity,
      'thinning': stroke.thinning,
      'smoothing': stroke.smoothing,
      'streamline': stroke.streamline,
      'simulatePressure': stroke.simulatePressure,
      'brushType': stroke.brushType?.name,
    };
  }

  static RasterStroke _rasterStrokeFromJson(Map<String, dynamic> json) {
    final pointsRaw = json['points'];
    final points = <PointVector>[];
    if (pointsRaw is List) {
      for (final entry in pointsRaw) {
        if (entry is List && entry.length >= 2) {
          final pressure = entry.length > 2 ? _num(entry[2], 1.0) : 1.0;
          points.add(
            PointVector(
              _num(entry[0], 0.0),
              _num(entry[1], 0.0),
              pressure,
            ),
          );
        }
      }
    }
    return RasterStroke(
      points: points,
      color: _color(json['color'], const Color(0xFF000000)),
      strokeWidth: _num(json['strokeWidth'], 2.0),
      opacity: _num(json['opacity'], 1.0),
      thinning: _num(json['thinning'], 0.5),
      smoothing: _num(json['smoothing'], 0.5),
      streamline: _num(json['streamline'], 0.5),
      simulatePressure: json['simulatePressure'] as bool? ?? true,
      brushType: _brushType(json['brushType']),
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
            (m) => {
              'timeMs': m.timeMs,
              'label': m.label,
              'kind': m.kind.name,
            },
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

  static Offset _offsetFromJson(dynamic value, {Offset fallback = Offset.zero}) {
    if (value is Map<String, dynamic>) {
      return Offset(_num(value['dx'], fallback.dx), _num(value['dy'], fallback.dy));
    }
    return fallback;
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
    if (value is int &&
        value >= 0 &&
        value < AudioMarkerKind.values.length) {
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

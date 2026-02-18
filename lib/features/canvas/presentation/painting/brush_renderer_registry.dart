import 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brush_renderer.dart';

/// Registry for brush renderers so new types can be added without switch blocks.
class BrushRendererRegistry {
  BrushRendererRegistry._();

  static final Map<BrushType, BrushRenderer Function()> _factories = {};
  static BrushRenderer Function()? _defaultFactory;
  static bool _defaultsRegistered = false;

  static void register(BrushType type, BrushRenderer Function() factory) {
    _factories[type] = factory;
  }

  static void registerDefault(BrushRenderer Function() factory) {
    _defaultFactory = factory;
  }

  static void ensureDefaultsRegistered() {
    if (_defaultsRegistered) return;
    _defaultsRegistered = true;
    register(BrushType.pencil, () => const PencilBrushRenderer(jitter: 0.4));
    register(BrushType.marker, () => const MarkerBrushRenderer());
    registerDefault(() => const PerfectFreehandRenderer());
  }

  static BrushRenderer getRenderer(BrushType? type) {
    ensureDefaultsRegistered();
    final factory = type != null ? _factories[type] : null;
    if (factory != null) {
      return factory();
    }
    return _defaultFactory?.call() ?? const PerfectFreehandRenderer();
  }
}

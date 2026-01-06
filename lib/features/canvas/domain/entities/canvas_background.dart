import 'dart:ui';

enum CanvasBackgroundKind { solid, transparent, image }

class CanvasBackground {
  const CanvasBackground({
    required this.kind,
    this.color,
    this.imagePath,
  });

  const CanvasBackground.solid(Color color)
      : kind = CanvasBackgroundKind.solid,
        color = color,
        imagePath = null;

  const CanvasBackground.transparent()
      : kind = CanvasBackgroundKind.transparent,
        color = null,
        imagePath = null;

  const CanvasBackground.image(String path, {Color? fallbackColor})
      : kind = CanvasBackgroundKind.image,
        color = fallbackColor,
        imagePath = path;

  final CanvasBackgroundKind kind;
  final Color? color;
  final String? imagePath;

  bool get isTransparent => kind == CanvasBackgroundKind.transparent;

  Color resolvedColor({Color fallback = const Color(0xFFFFFFFF)}) {
    return color ?? fallback;
  }
}

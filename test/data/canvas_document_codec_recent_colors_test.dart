import 'dart:ui';

import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CanvasDocumentCodec round-trips recent colors', () {
    final document = CanvasDocument.singleLayer(
      id: 'doc-recent-colors',
      title: 'Recent Colors',
      size: const Size(1920, 1080),
      fps: 24,
      recentColors: const <int>[
        0xFF112233,
        0xFF445566,
        0xFF778899,
      ],
    );

    final raw = CanvasDocumentCodec.encode(document);
    final decoded = CanvasDocumentCodec.decode(raw);

    expect(decoded.recentColors, document.recentColors);
  });
}

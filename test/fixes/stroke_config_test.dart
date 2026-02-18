import 'package:animation_maker/features/canvas/presentation/painting/stroke_render_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StrokeRenderConfig', () {
    group('smoothingForValue', () {
      test('returns minSmoothing for 0.0', () {
        expect(
          StrokeRenderConfig.smoothingForValue(0.0),
          equals(StrokeRenderConfig.minSmoothing),
        );
        expect(
          StrokeRenderConfig.smoothingForValue(0.0),
          equals(0.05),
        );
      });

      test('returns maxSmoothing for 1.0', () {
        expect(
          StrokeRenderConfig.smoothingForValue(1.0),
          equals(StrokeRenderConfig.maxSmoothing),
        );
        expect(
          StrokeRenderConfig.smoothingForValue(1.0),
          equals(0.8),
        );
      });

      test('returns midpoint for 0.5', () {
        final expected = (StrokeRenderConfig.minSmoothing +
                StrokeRenderConfig.maxSmoothing) /
            2;
        expect(
          StrokeRenderConfig.smoothingForValue(0.5),
          closeTo(expected, 0.0001),
        );
        expect(
          StrokeRenderConfig.smoothingForValue(0.5),
          closeTo(0.425, 0.0001),
        );
      });

      test('interpolates correctly for various values', () {
        expect(
          StrokeRenderConfig.smoothingForValue(0.25),
          closeTo(0.2375, 0.0001),
        );
        expect(
          StrokeRenderConfig.smoothingForValue(0.75),
          closeTo(0.6125, 0.0001),
        );
      });

      test('throws assertion error for values outside [0, 1]', () {
        expect(
          () => StrokeRenderConfig.smoothingForValue(-0.1),
          throwsAssertionError,
        );
        expect(
          () => StrokeRenderConfig.smoothingForValue(1.1),
          throwsAssertionError,
        );
      });
    });

    group('streamlineForValue', () {
      test('returns minStreamline for 0.0', () {
        expect(
          StrokeRenderConfig.streamlineForValue(0.0),
          equals(StrokeRenderConfig.minStreamline),
        );
        expect(
          StrokeRenderConfig.streamlineForValue(0.0),
          equals(0.05),
        );
      });

      test('returns maxStreamline for 1.0', () {
        expect(
          StrokeRenderConfig.streamlineForValue(1.0),
          equals(StrokeRenderConfig.maxStreamline),
        );
        expect(
          StrokeRenderConfig.streamlineForValue(1.0),
          equals(0.6),
        );
      });

      test('returns midpoint for 0.5', () {
        final expected = (StrokeRenderConfig.minStreamline +
                StrokeRenderConfig.maxStreamline) /
            2;
        expect(
          StrokeRenderConfig.streamlineForValue(0.5),
          closeTo(expected, 0.0001),
        );
        expect(
          StrokeRenderConfig.streamlineForValue(0.5),
          closeTo(0.325, 0.0001),
        );
      });

      test('interpolates correctly for various values', () {
        expect(
          StrokeRenderConfig.streamlineForValue(0.25),
          closeTo(0.1875, 0.0001),
        );
        expect(
          StrokeRenderConfig.streamlineForValue(0.75),
          closeTo(0.4625, 0.0001),
        );
      });

      test('throws assertion error for values outside [0, 1]', () {
        expect(
          () => StrokeRenderConfig.streamlineForValue(-0.1),
          throwsAssertionError,
        );
        expect(
          () => StrokeRenderConfig.streamlineForValue(1.1),
          throwsAssertionError,
        );
      });
    });

    group('parametersForValue', () {
      test('returns both smoothing and streamline for 0.0', () {
        final params = StrokeRenderConfig.parametersForValue(0.0);
        expect(params.smoothing, equals(0.05));
        expect(params.streamline, equals(0.05));
      });

      test('returns both smoothing and streamline for 1.0', () {
        final params = StrokeRenderConfig.parametersForValue(1.0);
        expect(params.smoothing, equals(0.8));
        expect(params.streamline, equals(0.6));
      });

      test('returns both smoothing and streamline for 0.5', () {
        final params = StrokeRenderConfig.parametersForValue(0.5);
        expect(params.smoothing, closeTo(0.425, 0.0001));
        expect(params.streamline, closeTo(0.325, 0.0001));
      });
    });

    group('StrokeParameters', () {
      test('equality works correctly', () {
        const params1 = StrokeParameters(smoothing: 0.5, streamline: 0.3);
        const params2 = StrokeParameters(smoothing: 0.5, streamline: 0.3);
        const params3 = StrokeParameters(smoothing: 0.6, streamline: 0.3);

        expect(params1, equals(params2));
        expect(params1, isNot(equals(params3)));
      });

      test('hashCode works correctly', () {
        const params1 = StrokeParameters(smoothing: 0.5, streamline: 0.3);
        const params2 = StrokeParameters(smoothing: 0.5, streamline: 0.3);
        const params3 = StrokeParameters(smoothing: 0.6, streamline: 0.3);

        expect(params1.hashCode, equals(params2.hashCode));
        expect(params1.hashCode, isNot(equals(params3.hashCode)));
      });

      test('toString works correctly', () {
        const params = StrokeParameters(smoothing: 0.5, streamline: 0.3);
        expect(
          params.toString(),
          equals('StrokeParameters(smoothing: 0.5, streamline: 0.3)'),
        );
      });
    });

    group('Consistency verification', () {
      test('old CanvasPainter values match new config at boundaries', () {
        // Old formula: 0.05 + slider * 0.85 (max was 0.9)
        // New formula: 0.05 + slider * 0.75 (max is 0.8)
        // This test verifies the NEW centralized config
        expect(StrokeRenderConfig.smoothingForValue(0.0), equals(0.05));
        expect(StrokeRenderConfig.smoothingForValue(1.0), equals(0.8));

        // Old streamline: 0.05 + slider * 0.75 (max was 0.8)
        // New streamline: 0.05 + slider * 0.55 (max is 0.6)
        expect(StrokeRenderConfig.streamlineForValue(0.0), equals(0.05));
        expect(StrokeRenderConfig.streamlineForValue(1.0), equals(0.6));
      });

      test('old ShapeEraseService values now match CanvasPainter', () {
        // Previously ShapeEraseService used different ranges:
        // smoothing: 0.05 + slider * 0.75
        // streamline: 0.05 + slider * 0.55
        // Now they both use the same StrokeRenderConfig

        for (double value = 0.0; value <= 1.0; value += 0.1) {
          final smoothing = StrokeRenderConfig.smoothingForValue(value);
          final streamline = StrokeRenderConfig.streamlineForValue(value);

          // Verify they're in valid ranges
          expect(smoothing, greaterThanOrEqualTo(0.05));
          expect(smoothing, lessThanOrEqualTo(0.8));
          expect(streamline, greaterThanOrEqualTo(0.05));
          expect(streamline, lessThanOrEqualTo(0.6));
        }
      });
    });

    group('Constants', () {
      test('have expected values', () {
        expect(StrokeRenderConfig.minSmoothing, equals(0.05));
        expect(StrokeRenderConfig.maxSmoothing, equals(0.8));
        expect(StrokeRenderConfig.minStreamline, equals(0.05));
        expect(StrokeRenderConfig.maxStreamline, equals(0.6));
        expect(StrokeRenderConfig.defaultThinning, equals(0.5));
      });

      test('min values are less than max values', () {
        expect(
          StrokeRenderConfig.minSmoothing,
          lessThan(StrokeRenderConfig.maxSmoothing),
        );
        expect(
          StrokeRenderConfig.minStreamline,
          lessThan(StrokeRenderConfig.maxStreamline),
        );
      });
    });
  });
}

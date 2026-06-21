import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';

void main() {
  group('computeUnionBounds', () {
    test('returns null for empty iterable', () {
      final result = computeUnionBounds([]);
      expect(result, isNull);
    });

    test('returns bounds for a single component', () {
      final component = PositionComponent()
        ..position = Vector2(10, 20)
        ..size = Vector2(30, 40);

      final result = computeUnionBounds([component]);
      expect(result, isNotNull);
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(20, 0.001));
      expect(result.$2.x, closeTo(30, 0.001));
      expect(result.$2.y, closeTo(40, 0.001));
    });

    test('returns union bounds for two components', () {
      final a = PositionComponent()
        ..position = Vector2(10, 20)
        ..size = Vector2(30, 40);
      final b = PositionComponent()
        ..position = Vector2(50, 10)
        ..size = Vector2(20, 60);

      final result = computeUnionBounds([a, b]);
      expect(result, isNotNull);
      // Min: (10, 10), Max: (70, 70), Size: (60, 60)
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(10, 0.001));
      expect(result.$2.x, closeTo(60, 0.001));
      expect(result.$2.y, closeTo(60, 0.001));
    });

    test('returns union bounds for non-overlapping components', () {
      final a = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(10, 10);
      final b = PositionComponent()
        ..position = Vector2(100, 200)
        ..size = Vector2(20, 30);

      final result = computeUnionBounds([a, b]);
      expect(result, isNotNull);
      // Min: (0, 0), Max: (120, 230)
      expect(result!.$1.x, closeTo(0, 0.001));
      expect(result.$1.y, closeTo(0, 0.001));
      expect(result.$2.x, closeTo(120, 0.001));
      expect(result.$2.y, closeTo(230, 0.001));
    });

    test('handles zero-size components as points', () {
      final a = PositionComponent()
        ..position = Vector2(50, 50)
        ..size = Vector2.zero();
      final b = PositionComponent()
        ..position = Vector2(10, 10)
        ..size = Vector2(20, 20);

      final result = computeUnionBounds([a, b]);
      expect(result, isNotNull);
      // Min: (10, 10), Max: (50, 50)
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(10, 0.001));
      expect(result.$2.x, closeTo(40, 0.001));
      expect(result.$2.y, closeTo(40, 0.001));
    });

    test('handles rotated components', () {
      final component = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(10, 10)
        ..angle = 3.141592653589793 / 2; // 90 degrees

      final result = computeUnionBounds([component]);
      expect(result, isNotNull);
      // After 90-degree rotation, the AABB should still be ~10x10
      // but shifted slightly due to rotation around the default topLeft anchor.
      // With topLeft anchor + 90deg rotation, corners map to:
      // (0,0) -> (0,0), (10,0) -> (0,10), (10,10) -> (-10,10), (0,10) -> (-10,0)
      // AABB: (-10, 0) to (0, 10) = size (10, 10)
      expect(result!.$2.x, closeTo(10, 0.1));
      expect(result.$2.y, closeTo(10, 0.1));
    });
  });

  group('computeChildrenBoundsLocal', () {
    test('returns null for parent with no children', () {
      final parent = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(100, 100);

      final result = computeChildrenBoundsLocal(parent);
      expect(result, isNull);
    });

    test('returns null when all children have zero size', () {
      final parent = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(100, 100);
      parent.add(
        PositionComponent()
          ..position = Vector2(10, 10)
          ..size = Vector2.zero(),
      );

      final result = computeChildrenBoundsLocal(parent);
      expect(result, isNull);
    });

    test('returns local bounds for single child', () {
      final parent = PositionComponent()
        ..position = Vector2(100, 100)
        ..size = Vector2(200, 200);
      parent.add(
        PositionComponent()
          ..position = Vector2(10, 20)
          ..size = Vector2(30, 40),
      );

      final result = computeChildrenBoundsLocal(parent);
      expect(result, isNotNull);
      // Child at local (10, 20) with size (30, 40)
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(20, 0.001));
      expect(result.$2.x, closeTo(30, 0.001));
      expect(result.$2.y, closeTo(40, 0.001));
    });

    test('returns union bounds for multiple children', () {
      final parent = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(200, 200);
      parent.add(
        PositionComponent()
          ..position = Vector2(10, 10)
          ..size = Vector2(20, 20),
      );
      parent.add(
        PositionComponent()
          ..position = Vector2(100, 80)
          ..size = Vector2(50, 60),
      );

      final result = computeChildrenBoundsLocal(parent);
      expect(result, isNotNull);
      // Min: (10, 10), Max: (150, 140)
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(10, 0.001));
      expect(result.$2.x, closeTo(140, 0.001));
      expect(result.$2.y, closeTo(130, 0.001));
    });

    test('skips zero-size children', () {
      final parent = PositionComponent()
        ..position = Vector2(0, 0)
        ..size = Vector2(200, 200);
      parent.add(
        PositionComponent()
          ..position = Vector2(10, 10)
          ..size = Vector2(20, 20),
      );
      parent.add(
        PositionComponent()
          ..position = Vector2(500, 500)
          ..size = Vector2.zero(),
      );

      final result = computeChildrenBoundsLocal(parent);
      expect(result, isNotNull);
      // Only the first child counts; zero-size child is skipped
      expect(result!.$1.x, closeTo(10, 0.001));
      expect(result.$1.y, closeTo(10, 0.001));
      expect(result.$2.x, closeTo(20, 0.001));
      expect(result.$2.y, closeTo(20, 0.001));
    });
  });
}

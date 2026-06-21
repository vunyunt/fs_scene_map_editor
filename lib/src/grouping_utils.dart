import 'package:flame/components.dart';

/// Computes the world-space axis-aligned bounding box (AABB) of a set of
/// position components.
///
/// Each component's four corners are transformed to world space via
/// [PositionComponent.absolutePositionOf], correctly handling rotation and
/// scale. Components with zero size contribute their [Component.absolutePosition]
/// as a degenerate point so they are still included in the bounds.
///
/// Returns `null` if [components] is empty.
///
/// Returns a record `(worldMin, worldSize)` where:
/// - `worldMin` is the top-left corner of the AABB in world coordinates.
/// - `worldSize` is the extent of the AABB.
(Vector2 worldMin, Vector2 worldSize)? computeUnionBounds(
  Iterable<PositionComponent> components,
) {
  final iterator = components.iterator;
  if (!iterator.moveNext()) return null;

  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  void expandWith(Vector2 point) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }

  do {
    final component = iterator.current;
    if (component.size.x > 0 && component.size.y > 0) {
      final corners = [
        Vector2.zero(),
        Vector2(component.size.x, 0),
        Vector2(component.size.x, component.size.y),
        Vector2(0, component.size.y),
      ];
      for (final corner in corners) {
        expandWith(component.absolutePositionOf(corner));
      }
    } else {
      expandWith(component.absolutePosition);
    }
  } while (iterator.moveNext());

  return (
    Vector2(minX, minY),
    Vector2(maxX - minX, maxY - minY),
  );
}

/// Computes the parent-local AABB of all [PositionComponent] children of
/// [parent].
///
/// This is used to compute a container component's size as the union of its
/// children's bounds, replacing the old first-child size inheritance.
///
/// Children with zero size are skipped to avoid recursion with size-inheriting
/// components (e.g. `ParentSized`).
///
/// Returns `null` if [parent] has no children with non-zero size.
(Vector2 localMin, Vector2 localSize)? computeChildrenBoundsLocal(
  PositionComponent parent,
) {
  double? minX;
  double? minY;
  double? maxX;
  double? maxY;

  for (final child in parent.children.whereType<PositionComponent>()) {
    if (child.size.isZero()) continue;

    final corners = [
      Vector2.zero(),
      Vector2(child.size.x, 0),
      Vector2(child.size.x, child.size.y),
      Vector2(0, child.size.y),
    ];

    for (final corner in corners) {
      final worldCorner = child.absolutePositionOf(corner);
      final localCorner = parent.absoluteToLocal(worldCorner);
      if (minX == null || localCorner.x < minX) minX = localCorner.x;
      if (minY == null || localCorner.y < minY) minY = localCorner.y;
      if (maxX == null || localCorner.x > maxX) maxX = localCorner.x;
      if (maxY == null || localCorner.y > maxY) maxY = localCorner.y;
    }
  }

  if (minX == null || minY == null || maxX == null || maxY == null) {
    return null;
  }

  return (
    Vector2(minX, minY),
    Vector2(maxX - minX, maxY - minY),
  );
}

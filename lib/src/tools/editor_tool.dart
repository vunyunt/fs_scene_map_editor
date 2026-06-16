import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../world_editor_controller.dart';

abstract class EditorTool {
  final WorldEditorController controller;

  EditorTool({required this.controller});

  bool get captureAllDrags => false;

  bool captureDragStart(DragStartEvent event) {
    if (captureAllDrags) return true;

    // Check if the click is on/near any selected component
    final selected = controller.selectionManager.selectedComponents;
    if (selected.isEmpty) return false;

    for (final component in selected) {
      if (component is PositionComponent) {
        if (_isNearComponent(component, event.localPosition)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isNearComponent(PositionComponent component, Vector2 point) {
    if (component.size.x > 0 && component.size.y > 0) {
      final localPoint = component.absoluteToLocal(point);
      const margin = 0.5; // margin in world units
      if (localPoint.x >= -margin &&
          localPoint.x <= component.size.x + margin &&
          localPoint.y >= -margin &&
          localPoint.y <= component.size.y + margin) {
        return true;
      }
    } else {
      // If size is zero (like spline component empty parents),
      // check if the point is close to the position itself
      final dist = component.absolutePosition.distanceTo(point);
      if (dist <= 1.0) return true;
    }

    for (final child in component.children.whereType<PositionComponent>()) {
      final localPoint = child.absoluteToLocal(point);
      if (child.containsLocalPoint(localPoint)) {
        return true;
      }
      if (_isNearComponent(child, point)) {
        return true;
      }
    }
    return false;
  }

  void onTapDown(TapDownEvent event) {}
  void onDragStart(DragStartEvent event) {}
  void onDragUpdate(DragUpdateEvent event) {}
  void onDragEnd(DragEndEvent event) {}

  void onActivate() {}
  void onDeactivate() {}

  void update(double dt) {}
  void render(Canvas canvas) {}
}

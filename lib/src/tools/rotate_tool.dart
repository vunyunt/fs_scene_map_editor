import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../commands/editor_command.dart';
import 'editor_tool.dart';
import 'package:fs_scene_map/fs_scene_map.dart';

class RotateTool extends EditorTool {
  RotateTool({required super.controller});

  final Map<PositionComponent, double> _startAngles = {};
  Vector2? _dragStartPoint;

  @override
  void onDragStart(DragStartEvent event) {
    _startAngles.clear();
    final selected = controller.selectionManager.selectedComponents
        .whereType<PositionComponent>();

    if (selected.isEmpty) return;

    for (final component in selected) {
      _startAngles[component] = component.angle;
    }
    _dragStartPoint = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragStartPoint == null) return;

    for (final component in _startAngles.keys) {
      component.angle += event.localDelta.x * 0.01;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_dragStartPoint == null) return;

    final commands = <EditorCommand>[];
    for (final entry in _startAngles.entries) {
      final component = entry.key;
      final startAngle = entry.value;
      final endAngle = component.angle;

      if (startAngle != endAngle) {
        commands.add(
          RotateCommand(
            target: component,
            oldAngle: startAngle,
            newAngle: endAngle,
            delegate: controller.delegate,
          ),
        );
      }
    }

    if (commands.isNotEmpty) {
      controller.commandManager.execute(
        commands.length == 1 ? commands.first : CompositeCommand(commands),
      );

      final spatialController = controller.game.world.spatialChunkController;
      if (spatialController != null) {
        for (final component in _startAngles.keys) {
          spatialController.markDirty(component);
        }
      }
    }

    _dragStartPoint = null;
    _startAngles.clear();
  }
}

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../commands/editor_command.dart';
import '../snapping_utils.dart';
import 'editor_tool.dart';
import 'package:fs_scene_map/fs_scene_map.dart';

class MoveTool extends EditorTool {
  MoveTool({required super.controller, this.gridSize = 0});

  final double gridSize;
  final Map<PositionComponent, Vector2> _startPositions = {};
  Vector2? _dragStartPoint;

  @override
  void onDragStart(DragStartEvent event) {
    _startPositions.clear();
    final selected = controller.selectionManager.selectedComponents
        .whereType<PositionComponent>();

    if (selected.isEmpty) return;

    for (final component in selected) {
      _startPositions[component] = component.position.clone();
    }
    _dragStartPoint = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragStartPoint == null) return;

    for (final component in _startPositions.keys) {
      component.position += event.localDelta;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_dragStartPoint == null) return;

    final commands = <EditorCommand>[];
    for (final entry in _startPositions.entries) {
      final component = entry.key;

      if (gridSize > 0) {
        component.position = SnappingUtils.snapVector(component.position, gridSize);
      }

      final startPos = entry.value;
      final endPos = component.position.clone();

      if (startPos != endPos) {
        commands.add(
          MoveCommand(
            target: component,
            oldPosition: startPos,
            newPosition: endPos,
            delegate: controller.delegate,
          ),
        );
      }
    }

    if (commands.isNotEmpty) {
      controller.commandManager.execute(
        commands.length == 1 ? commands.first : CompositeCommand(commands),
      );

      // Re-parent components if they moved across chunks
      final spatialController = controller.game.world.spatialChunkController;
      if (spatialController != null) {
        for (final component in _startPositions.keys) {
          spatialController.reparentComponent(component);
        }
      }
    }

    _dragStartPoint = null;
    _startPositions.clear();
  }
}

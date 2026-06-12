import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../commands/editor_command.dart';
import 'editor_tool.dart';
import 'package:fs_scene_map/fs_scene_map.dart';

class ScaleTool extends EditorTool {
  ScaleTool({required super.controller});

  final Map<PositionComponent, Vector2> _startScales = {};
  Vector2? _dragStartPoint;

  @override
  void onDragStart(DragStartEvent event) {
    _startScales.clear();
    final selected = controller.selectionManager.selectedComponents
        .whereType<PositionComponent>();

    if (selected.isEmpty) return;

    for (final component in selected) {
      _startScales[component] = component.scale.clone();
    }
    _dragStartPoint = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragStartPoint == null) return;

    for (final component in _startScales.keys) {
      final delta = event.localDelta.y * 0.01;
      component.scale += Vector2(delta, delta);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_dragStartPoint == null) return;

    final commands = <EditorCommand>[];
    for (final entry in _startScales.entries) {
      final component = entry.key;
      final startScale = entry.value;
      final endScale = component.scale.clone();

      if (startScale != endScale) {
        commands.add(
          ScaleCommand(
            target: component,
            oldScale: startScale,
            newScale: endScale,
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
        for (final component in _startScales.keys) {
          spatialController.markDirty(component);
        }
      }
    }

    _dragStartPoint = null;
    _startScales.clear();
  }
}

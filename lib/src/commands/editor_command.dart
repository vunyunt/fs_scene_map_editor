import 'package:flame/components.dart';
import '../editor_interfaces.dart';

abstract class EditorCommand {
  const EditorCommand();

  void execute();
  void undo();
}

class MoveCommand extends EditorCommand {
  final PositionComponent target;
  final Vector2 oldPosition;
  final Vector2 newPosition;
  final SceneMapEditorDelegate delegate;

  MoveCommand({
    required this.target,
    required this.oldPosition,
    required this.newPosition,
    required this.delegate,
  });

  @override
  void execute() => delegate.updatePosition(target, newPosition);

  @override
  void undo() => delegate.updatePosition(target, oldPosition);
}

class RotateCommand extends EditorCommand {
  final PositionComponent target;
  final double oldAngle;
  final double newAngle;
  final SceneMapEditorDelegate delegate;

  RotateCommand({
    required this.target,
    required this.oldAngle,
    required this.newAngle,
    required this.delegate,
  });

  @override
  void execute() => delegate.updateAngle(target, newAngle);

  @override
  void undo() => delegate.updateAngle(target, oldAngle);
}

class ScaleCommand extends EditorCommand {
  final PositionComponent target;
  final Vector2 oldScale;
  final Vector2 newScale;
  final SceneMapEditorDelegate delegate;

  ScaleCommand({
    required this.target,
    required this.oldScale,
    required this.newScale,
    required this.delegate,
  });

  @override
  void execute() => delegate.updateScale(target, newScale);

  @override
  void undo() => delegate.updateScale(target, oldScale);
}

class CompositeCommand extends EditorCommand {
  final List<EditorCommand> commands;

  CompositeCommand(this.commands);

  @override
  void execute() {
    for (final command in commands) {
      command.execute();
    }
  }

  @override
  void undo() {
    for (final command in commands.reversed) {
      command.undo();
    }
  }
}

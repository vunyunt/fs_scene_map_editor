import 'dart:ui';
import 'package:flame/events.dart';
import '../world_editor_controller.dart';

abstract class EditorTool {
  final WorldEditorController controller;

  EditorTool({required this.controller});

  void onTapDown(TapDownEvent event) {}
  void onDragStart(DragStartEvent event) {}
  void onDragUpdate(DragUpdateEvent event) {}
  void onDragEnd(DragEndEvent event) {}

  void onActivate() {}
  void onDeactivate() {}

  void update(double dt) {}
  void render(Canvas canvas) {}
}

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';

class TestEditorGame extends FlameGame with EditorGameHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSceneMapEditorDelegate implements SceneMapEditorDelegate {
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WorldEditorController> _loadController(
  TestEditorGame game,
  WorldEditorSelectionManager selectionManager,
  Set<LogicalKeyboardKey> Function() logicalKeysPressed,
) async {
  await game.load();
  game.mount();
  game.onGameResize(Vector2(800, 600));

  final controller = WorldEditorController(
    selectionManager: selectionManager,
    delegate: TestSceneMapEditorDelegate(),
    logicalKeysPressed: logicalKeysPressed,
  );

  await game.world.add(controller);
  game.update(0);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldEditorController', () {
    test('alt left drag pans the camera over empty space', () async {
      final game = TestEditorGame();
      final selectionManager = WorldEditorSelectionManager();
      final controller = await _loadController(
        game,
        selectionManager,
        () => {LogicalKeyboardKey.altLeft},
      );

      game.camera.viewfinder.zoom = 2;
      final startPosition = game.camera.viewfinder.position.clone();

      controller.onDragStart(
        DragStartEvent(
          1,
          game,
          DragStartDetails(
            globalPosition: Offset.zero,
            kind: PointerDeviceKind.mouse,
          ),
        ),
      );
      controller.onDragUpdate(
        DragUpdateEvent(
          1,
          game,
          DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: Offset(20, -10),
          ),
        ),
      );
      controller.onDragEnd(DragEndEvent(1, DragEndDetails()));

      expect(
        game.camera.viewfinder.position.x,
        closeTo(startPosition.x - 10, 0.001),
      );
      expect(
        game.camera.viewfinder.position.y,
        closeTo(startPosition.y + 5, 0.001),
      );
    });

    test('alt tap does not change selection', () async {
      final game = TestEditorGame();
      final selected = Component();
      final selectionManager = WorldEditorSelectionManager()..select(selected);
      final controller = await _loadController(
        game,
        selectionManager,
        () => {LogicalKeyboardKey.altLeft},
      );

      controller.onTapDown(
        TapDownEvent(
          1,
          game,
          TapDownDetails(globalPosition: const Offset(100, 100)),
        ),
      );

      expect(selectionManager.selectedComponents, contains(selected));
    });
  });
}

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';

class TestEditorGame extends FlameGame with EditorGameHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSceneMapEditorDelegate implements SceneMapEditorDelegate {
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSceneMapEditorDelegateWithPaste implements SceneMapEditorDelegate {
  final List<(Vector2, dynamic)> pastes = [];

  @override
  void onPaste(Vector2 worldPos, dynamic childAny) {
    pastes.add((worldPos, childAny));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProtoSerializableComponent extends PositionComponent with ProtoSerializable<Any> {
  MockProtoSerializableComponent() {
    position = Vector2(100, 200);
  }

  @override
  Any get data => Any();
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

    test('delete key deletes selected components', () async {
      final game = TestEditorGame();
      final target = Component();
      final selectionManager = WorldEditorSelectionManager()..select(target);
      final deleted = <Component>[];
      final delegate = TestSceneMapEditorDelegateWithDelete(deleted);

      await game.load();
      game.mount();
      game.onGameResize(Vector2(800, 600));

      final controller = WorldEditorController(
        selectionManager: selectionManager,
        delegate: delegate,
      );

      await game.world.add(controller);
      game.update(0);

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.delete,
        logicalKey: LogicalKeyboardKey.delete,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(event, {LogicalKeyboardKey.delete});

      expect(handled, isTrue);
      expect(deleted, contains(target));
      expect(selectionManager.hasSelection, isFalse);
    });

    test('custom key bindings override or extend default bindings', () async {
      final game = TestEditorGame();
      final selectionManager = WorldEditorSelectionManager();
      var customSaveCalled = false;
      var customActionCalled = false;

      await game.load();
      game.mount();
      game.onGameResize(Vector2(800, 600));

      final controller = WorldEditorController(
        selectionManager: selectionManager,
        delegate: TestSceneMapEditorDelegate(),
        customKeyBindings: {
          // Override save shortcut
          (key: LogicalKeyboardKey.keyS, control: true, shift: false, alt: false): (c) {
            customSaveCalled = true;
            return true;
          },
          // Add custom shortcut (Ctrl + G)
          (key: LogicalKeyboardKey.keyG, control: true, shift: false, alt: false): (c) {
            customActionCalled = true;
            return true;
          },
        },
      );

      await game.world.add(controller);
      game.update(0);

      // Trigger Ctrl + S
      final saveEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );
      final saveHandled = controller.onKeyEvent(
        saveEvent,
        {LogicalKeyboardKey.keyS, LogicalKeyboardKey.controlLeft},
      );

      // Trigger Ctrl + G
      final gEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyG,
        logicalKey: LogicalKeyboardKey.keyG,
        timeStamp: Duration.zero,
      );
      final gHandled = controller.onKeyEvent(
        gEvent,
        {LogicalKeyboardKey.keyG, LogicalKeyboardKey.controlLeft},
      );

      expect(saveHandled, isTrue);
      expect(customSaveCalled, isTrue);

      expect(gHandled, isTrue);
      expect(customActionCalled, isTrue);
    });

    test('Escape key clears selection', () async {
      final game = TestEditorGame();
      final target = Component();
      final selectionManager = WorldEditorSelectionManager()..select(target);
      final controller = await _loadController(game, selectionManager, () => {});

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(event, {LogicalKeyboardKey.escape});

      expect(handled, isTrue);
      expect(selectionManager.hasSelection, isFalse);
    });

    test('F key focuses selection', () async {
      final game = TestEditorGame();
      final target = PositionComponent()..position = Vector2(500, -300);
      final selectionManager = WorldEditorSelectionManager()..select(target);
      final controller = await _loadController(game, selectionManager, () => {});

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: LogicalKeyboardKey.keyF,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(event, {LogicalKeyboardKey.keyF});

      expect(handled, isTrue);
      expect(game.camera.viewfinder.position.x, closeTo(500, 0.001));
      expect(game.camera.viewfinder.position.y, closeTo(-300, 0.001));
    });

    test('Ctrl + D duplicates selection', () async {
      final game = TestEditorGame();
      final target = MockProtoSerializableComponent();
      final selectionManager = WorldEditorSelectionManager()..select(target);
      final delegate = TestSceneMapEditorDelegateWithPaste();

      await game.load();
      game.mount();
      game.onGameResize(Vector2(800, 600));

      final controller = WorldEditorController(
        selectionManager: selectionManager,
        delegate: delegate,
      );

      await game.world.add(controller);
      game.update(0);

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyD,
        logicalKey: LogicalKeyboardKey.keyD,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(
        event,
        {LogicalKeyboardKey.keyD, LogicalKeyboardKey.controlLeft},
      );

      expect(handled, isTrue);
      expect(delegate.pastes, hasLength(1));
      expect(delegate.pastes.first.$1.x, closeTo(132, 0.001));
      expect(delegate.pastes.first.$1.y, closeTo(232, 0.001));
    });

    test('Ctrl + Equal / Ctrl + Minus / Ctrl + Digit0 adjust zoom', () async {
      final game = TestEditorGame();
      final selectionManager = WorldEditorSelectionManager();
      final controller = await _loadController(game, selectionManager, () => {});

      game.camera.viewfinder.zoom = 1.0;

      // Zoom In
      final zoomInEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.equal,
        logicalKey: LogicalKeyboardKey.equal,
        timeStamp: Duration.zero,
      );
      var handled = controller.onKeyEvent(
        zoomInEvent,
        {LogicalKeyboardKey.equal, LogicalKeyboardKey.controlLeft},
      );
      expect(handled, isTrue);
      expect(game.camera.viewfinder.zoom, closeTo(1.2, 0.001));

      // Zoom Out
      final zoomOutEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.minus,
        logicalKey: LogicalKeyboardKey.minus,
        timeStamp: Duration.zero,
      );
      handled = controller.onKeyEvent(
        zoomOutEvent,
        {LogicalKeyboardKey.minus, LogicalKeyboardKey.controlLeft},
      );
      expect(handled, isTrue);
      expect(game.camera.viewfinder.zoom, closeTo(1.0, 0.001));

      // Zoom Out again
      handled = controller.onKeyEvent(
        zoomOutEvent,
        {LogicalKeyboardKey.minus, LogicalKeyboardKey.controlLeft},
      );
      expect(handled, isTrue);
      expect(game.camera.viewfinder.zoom, closeTo(1.0 / 1.2, 0.001));

      // Reset Zoom
      final resetEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit0,
        logicalKey: LogicalKeyboardKey.digit0,
        timeStamp: Duration.zero,
      );
      handled = controller.onKeyEvent(
        resetEvent,
        {LogicalKeyboardKey.digit0, LogicalKeyboardKey.controlLeft},
      );
      expect(handled, isTrue);
      expect(game.camera.viewfinder.zoom, closeTo(1.0, 0.001));
    });

    test('1, 2, 3 digits switch active tool', () async {
      final game = TestEditorGame();
      final selectionManager = WorldEditorSelectionManager();
      final controller = await _loadController(game, selectionManager, () => {});

      // Use Rotate Tool by default first to check if 1 switches to MoveTool
      controller.useRotateTool();
      expect(controller.activeToolType.value, RotateTool);

      // Press 1 to switch to MoveTool
      final event1 = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.digit1,
        timeStamp: Duration.zero,
      );
      var handled = controller.onKeyEvent(event1, {LogicalKeyboardKey.digit1});
      expect(handled, isTrue);
      expect(controller.activeToolType.value, MoveTool);

      // Press 2 to switch to RotateTool
      final event2 = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit2,
        logicalKey: LogicalKeyboardKey.digit2,
        timeStamp: Duration.zero,
      );
      handled = controller.onKeyEvent(event2, {LogicalKeyboardKey.digit2});
      expect(handled, isTrue);
      expect(controller.activeToolType.value, RotateTool);

      // Press 3 to switch to ScaleTool
      final event3 = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit3,
        logicalKey: LogicalKeyboardKey.digit3,
        timeStamp: Duration.zero,
      );
      handled = controller.onKeyEvent(event3, {LogicalKeyboardKey.digit3});
      expect(handled, isTrue);
      expect(controller.activeToolType.value, ScaleTool);
    });
  });
}

class TestSceneMapEditorDelegateWithDelete implements SceneMapEditorDelegate {
  final List<Component> deleted;
  TestSceneMapEditorDelegateWithDelete(this.deleted);

  @override
  void onDeleteComponent(Component component) {
    deleted.add(component);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

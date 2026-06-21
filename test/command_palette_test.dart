import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';

class TestEditorGame extends FlameGame with EditorGameHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSceneMapEditorDelegate implements SceneMapEditorDelegate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Command Palette Tests', () {
    test('Ctrl + Shift + P triggers command palette request', () async {
      final game = TestEditorGame();
      final selectionManager = WorldEditorSelectionManager();
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      game.onGameResize(Vector2(800, 600));

      final controller = WorldEditorController(
        selectionManager: selectionManager,
        delegate: TestSceneMapEditorDelegate(),
      );

      await game.world.add(controller);
      game.update(0);

      expect(controller.commandPaletteRequest.value, isFalse);

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(
        event,
        {
          LogicalKeyboardKey.keyP,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.shiftLeft,
        },
      );

      expect(handled, isTrue);
      expect(controller.commandPaletteRequest.value, isTrue);
    });

    test('allCommands contains default commands', () {
      final controller = WorldEditorController(
        selectionManager: WorldEditorSelectionManager(),
        delegate: TestSceneMapEditorDelegate(),
      );

      final commands = controller.allCommands;

      // Verify built-in commands exist
      final saveCmd = commands.firstWhere((cmd) => cmd.id == 'save');
      expect(saveCmd.label, equals('Save Scene'));
      expect(saveCmd.shortcutText, equals('Ctrl+S'));

      final zoomInCmd = commands.firstWhere((cmd) => cmd.id == 'zoom_in');
      expect(zoomInCmd.label, equals('Zoom In'));

      final paletteCmd = commands.firstWhere((cmd) => cmd.id == 'command_palette');
      expect(paletteCmd.label, equals('Show Command Palette'));
      expect(paletteCmd.shortcutText, equals('Ctrl+Shift+P'));
    });

    test('customCommands are registered and merged', () {
      final customCmd = EditorCommandMetadata(
        id: 'test_custom',
        label: 'Test Custom Command',
        description: 'Does something custom',
        shortcutText: 'Ctrl+Alt+C',
        action: (c) => true,
      );

      final controller = WorldEditorController(
        selectionManager: WorldEditorSelectionManager(),
        delegate: TestSceneMapEditorDelegate(),
        customCommands: [customCmd],
      );

      final commands = controller.allCommands;
      expect(commands, contains(customCmd));
      expect(controller.customCommands, contains(customCmd));
    });
  });
}

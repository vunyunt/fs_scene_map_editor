import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';

class TestEditorGame extends FlameGame with EditorGameHost {
  @override
  final serializableComponentRegistry = MockSerializableComponentRegistry();

  @override
  String getComponentName(GeneratedMessage proto) => 'Test Message';

  @override
  String getComponentShortDescription(GeneratedMessage proto) => 'Test Description';

  @override
  Int64 nextId() => Int64(42);

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

    test('Ctrl+Shift+I triggers add component palette request', () async {
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
        physicalKey: PhysicalKeyboardKey.keyI,
        logicalKey: LogicalKeyboardKey.keyI,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(
        event,
        {
          LogicalKeyboardKey.keyI,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.shiftLeft,
        },
      );

      expect(handled, isTrue);
      expect(controller.commandPaletteRequest.value, isTrue);
      expect(controller.commandPalettePrefix.value, equals('+'));
    });

    test('Shift+A triggers add component palette request', () async {
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
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );

      final handled = controller.onKeyEvent(
        event,
        {
          LogicalKeyboardKey.keyA,
          LogicalKeyboardKey.shiftLeft,
        },
      );

      expect(handled, isTrue);
      expect(controller.commandPaletteRequest.value, isTrue);
      expect(controller.commandPalettePrefix.value, equals('+'));
    });

    test('paletteComponentCommands only includes components implementing PaletteComponentMeta with showInPalette', () async {
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

      // Verify that it is empty first
      expect(controller.paletteComponentCommands, isEmpty);

      // Now register our test message
      final descriptor = ComponentDescriptor(
        defaultInstance: MockGeneratedMessage(),
        factory: (data, {registry}) => MockProtoSerializable(data as MockGeneratedMessage),
        meta: const TestPaletteMeta(),
      );
      game.serializableComponentRegistry.registerDescriptor(descriptor);

      final commands = controller.paletteComponentCommands;
      expect(commands, hasLength(1));
      expect(commands.first.id, equals('add_component_test.MockGeneratedMessage'));
      expect(commands.first.label, equals('Test Component'));
      expect(commands.first.description, equals('A test component for palette'));
    });
  });
}

class MockGeneratedMessage extends GeneratedMessage {
  @override
  MockGeneratedMessage clone() => MockGeneratedMessage();
  @override
  MockGeneratedMessage copyWith(void Function(MockGeneratedMessage) _) => MockGeneratedMessage();
  @override
  BuilderInfo get info_ => BuilderInfo('MockGeneratedMessage', package: const PackageName('test'));
  @override
  MockGeneratedMessage createEmptyInstance() => MockGeneratedMessage();
}

class TestPaletteMeta extends ProtoComponentMeta<MockGeneratedMessage> implements PaletteComponentMeta {
  const TestPaletteMeta();
  @override
  bool get showInPalette => true;
  @override
  String? get paletteLabel => 'Test Component';
  @override
  String? get paletteDescription => 'A test component for palette';
  @override
  String get paletteCategory => 'Test';
}

class MockProtoSerializable with ProtoSerializable<MockGeneratedMessage> {
  @override
  final MockGeneratedMessage data;
  MockProtoSerializable(this.data);
  @override
  MockGeneratedMessage serialize() => data;
}

class MockSerializableComponentRegistry extends SerializableComponentRegistry {
  MockSerializableComponentRegistry() : super(typeRegistry: TypeRegistry([]));
}

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
import 'package:protobuf_message_editor/protobuf_message_editor.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'world_editor_controller.dart';

mixin EditorGameHost on FlameGame {
  SerializableComponentRegistry get serializableComponentRegistry;
  GenericDescriptorRegistry get descriptorRegistry;
  TypeRegistry get typeRegistry;
  ProtoMapEditorProvider get editorProvider;
  Int64 nextId();

  String getComponentName(GeneratedMessage proto);
  String getComponentShortDescription(GeneratedMessage proto);
  IconData? getComponentIcon(GeneratedMessage proto);

  void pushWorld(World Function() builder);
  void popWorld();
}

abstract class SceneMapEditorDelegate {
  void updatePosition(PositionComponent component, Vector2 position);
  void updateScale(PositionComponent component, Vector2 scale);
  void updateAngle(PositionComponent component, double angle);

  void onDeleteComponent(Component component);
  void onAddChild(PositionComponent parent, Any childAny);
  void onCreateComponent(Vector2 worldPos, Any childAny);
}

abstract class AssetImportDelegate {
  Future<void> onDropDone(BuildContext context, DropDoneDetails details, Vector2 worldPos);
  Widget? buildAssetButton(BuildContext context, PositionComponent target);
}

typedef ChildSelectorBuilder = Widget Function(
  BuildContext context,
  PositionComponent? parent,
  void Function(Any childAny) onConfirm,
  VoidCallback onCancel,
);

typedef ContextualToolbarBuilder = List<Widget> Function(
  BuildContext context,
  PositionComponent target,
  WorldEditorController controller,
);


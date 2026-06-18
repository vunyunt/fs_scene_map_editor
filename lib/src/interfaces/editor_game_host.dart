import 'package:fixnum/fixnum.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf_message_editor/protobuf_message_editor.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';

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

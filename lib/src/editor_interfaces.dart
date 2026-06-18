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

export './interfaces/asset_import_delegate.dart';
export './interfaces/editor_game_host.dart';
export './interfaces/scene_map_editor_delegate.dart';

typedef ChildSelectorBuilder =
    Widget Function(
      BuildContext context,
      PositionComponent? parent,
      void Function(Any childAny) onConfirm,
      VoidCallback onCancel,
    );

typedef ContextualToolbarBuilder =
    List<Widget> Function(
      BuildContext context,
      PositionComponent target,
      WorldEditorController controller,
    );

import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
import 'world_editor_controller.dart';

class EditorCommandMetadata {
  final String id;
  final String label;
  final String description;
  final String shortcutText;
  final List<EditorShortcutActivator> shortcuts;
  final bool showInPalette;
  final EditorControllerAction action;

  const EditorCommandMetadata({
    required this.id,
    required this.label,
    required this.description,
    required this.shortcutText,
    this.shortcuts = const [],
    this.showInPalette = true,
    required this.action,
  });
}

class AddComponentCommandMetadata extends EditorCommandMetadata {
  AddComponentCommandMetadata({
    required super.id,
    required super.label,
    required super.description,
    required ComponentDescriptor descriptor,
    super.shortcuts = const [],
    super.showInPalette = true,
  }) : super(
         shortcutText: '',
         action: (controller) {
            final newInstance = descriptor.defaultInstance.deepCopy();
            final idField = newInstance.info_.fieldInfo[1];
            if (idField != null && (idField.name == 'id' || idField.name == '_id')) {
              newInstance.setField(1, controller.game.nextId());
            } else {
              print('[INFO] Component created without an ID field at tag 1: ${descriptor.defaultInstance.info_.qualifiedMessageName}');
            }
            final worldPos = controller.mousePosition;
            controller.delegate.onCreateComponent(worldPos, Any.pack(newInstance));
            return true;
         },
       );
}

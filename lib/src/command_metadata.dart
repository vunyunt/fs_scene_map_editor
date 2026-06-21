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

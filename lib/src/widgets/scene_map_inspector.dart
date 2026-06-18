import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:protobuf_message_editor/protobuf_message_editor.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:provider/provider.dart';
import 'package:fs_scene_map/fs_scene_map.dart';
import '../editor_interfaces.dart';
import '../world_editor_selection_manager.dart';

class SceneMapInspector extends StatefulWidget {
  const SceneMapInspector({super.key});

  @override
  State<SceneMapInspector> createState() => _SceneMapInspectorState();
}

class _SceneMapInspectorState extends State<SceneMapInspector> {
  @override
  Widget build(BuildContext context) {
    final game = context.read<EditorGameHost>();
    final selectionManager = context.watch<WorldEditorSelectionManager>();

    if (!selectionManager.hasSelection) {
      final world = game.world;
      if (world is! ProtoSerializable) {
        return const Center(
          child: Text('Select a component to view properties'),
        );
      }

      Widget buildWorldEditor() {
        final serializable = world as ProtoSerializable;
        final proto = serializable.serialize();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'World Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            Expanded(
              child: ProtoMapEditor(
                message: proto,
                typeRegistry: game.typeRegistry,
                provider: game.editorProvider,
                onSave: (updated) {
                  serializable.modify((data) {
                    data.clear();
                    data.mergeFromMessage(updated);
                  });
                },
              ),
            ),
          ],
        );
      }

      if (world is Listenable) {
        return ListenableBuilder(
          listenable: world as Listenable,
          builder: (context, _) => buildWorldEditor(),
        );
      } else {
        return buildWorldEditor();
      }
    }

    final selected = selectionManager.primarySelection;
    if (selected == null) {
      return const Center(child: Text('Select a component to view properties'));
    }

    if (selected is! ProtoSerializable) {
      return const Center(child: Text('Selected component is not editable'));
    }

    final serializable = selected as ProtoSerializable;
    final proto = serializable.serialize();
    final registry = game.serializableComponentRegistry;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Inspector: ${selected.runtimeType}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(),
        _buildHierarchyToolbar(
          context,
          serializable,
          selectionManager,
          registry,
        ),
        Expanded(
          child: ProtoMapEditor(
            message: proto,
            typeRegistry: game.typeRegistry,
            provider: game.editorProvider,
            onSave: (updated) {
              serializable.modify((data) {
                data.clear();
                data.mergeFromMessage(updated);
              });

              // Notify spatial chunking system about the change
              final spatialController = game.world.spatialChunkController;
              if (spatialController != null) {
                spatialController.reparentComponent(selected);
              }

              // If this is a child component, notify the parent that its data might be out of sync
              final parent = selected.parent;
              if (parent is ProtoSerializable) {
                (parent as ProtoSerializable).modify((_) {});
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHierarchyToolbar(
    BuildContext context,
    ProtoSerializable selected,
    WorldEditorSelectionManager selectionManager,
    SerializableComponentRegistry registry,
  ) {
    final game = context.read<EditorGameHost>();
    final component = selected as Component;
    final parent = component.parent;
    final hasParent = parent is ProtoSerializable;
    final children = component.children.whereType<ProtoSerializable>().toList();

    if (!hasParent && children.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          if (hasParent) ...[
            Tooltip(
              message:
                  'Go to Parent: ${game.getComponentName((parent as ProtoSerializable).serialize())}',
              child: IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: () {
                  selectionManager.clear();
                  selectionManager.select(parent as Component);
                },
              ),
            ),
            VerticalDivider(
              width: 1,
              indent: 12,
              endIndent: 12,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ],
          Expanded(
            child: children.isEmpty
                ? Center(
                    child: Text(
                      'No children components',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.5,
                        ),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: children.map((child) {
                        final childProto = child.serialize();
                        final childIcon = game.getComponentIcon(childProto);
                        final childName = game.getComponentName(childProto);
                        final childDesc = game.getComponentShortDescription(
                          childProto,
                        );

                        final nameParts = childProto.info_.qualifiedMessageName
                            .split('.');
                        final initial = nameParts.last.isNotEmpty
                            ? nameParts.last.substring(0, 1).toUpperCase()
                            : '?';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Tooltip(
                            message:
                                '$childName${childDesc.isNotEmpty ? "\n$childDesc" : ""}',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                selectionManager.clear();
                                selectionManager.select(child as Component);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: childIcon != null
                                    ? Icon(
                                        childIcon,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      )
                                    : Text(
                                        initial,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

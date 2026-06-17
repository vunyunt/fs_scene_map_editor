import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../world_editor_controller.dart';
import '../tools/move_tool.dart';
import '../tools/rotate_tool.dart';
import '../tools/scale_tool.dart';
import '../editor_interfaces.dart';
import 'package:provider/provider.dart';

class WorldEditorContextualToolbar extends StatefulWidget {
  final WorldEditorController controller;

  const WorldEditorContextualToolbar({super.key, required this.controller});

  @override
  State<WorldEditorContextualToolbar> createState() =>
      _WorldEditorContextualToolbarState();
}

class _WorldEditorContextualToolbarState
    extends State<WorldEditorContextualToolbar> {
  bool _showAddChild = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller.selectionManager,
        widget.controller.activeToolType,
      ]),
      builder: (context, _) {
        final selected = widget.controller.selectionManager.selectedComponents;
        if (selected.isEmpty) return const SizedBox.shrink();

        final target = selected.first;
        if (target is! PositionComponent) return const SizedBox.shrink();

        final game = context.read<EditorGameHost>();

        final localTopCenter = Vector2(target.size.x / 2, 0);
        final worldTopCenter = target.absolutePositionOf(localTopCenter);
        final canvasPosition = game.camera.localToGlobal(worldTopCenter);
        final screenPosition = canvasPosition;

        return Stack(
          children: [
            Positioned(
              left: screenPosition.x - 100,
              top: screenPosition.y - 60,
              child: Material(
                elevation: 4,
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToolButton(
                        context,
                        icon: Icons.open_with,
                        tooltip: 'Move Tool',
                        isActive: widget.controller.activeTool is MoveTool,
                        onPressed: widget.controller.useMoveTool,
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.rotate_right,
                        tooltip: 'Rotate Tool',
                        isActive: widget.controller.activeTool is RotateTool,
                        onPressed: widget.controller.useRotateTool,
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.aspect_ratio,
                        tooltip: 'Scale Tool',
                        isActive: widget.controller.activeTool is ScaleTool,
                        onPressed: widget.controller.useScaleTool,
                      ),
                      const SizedBox(
                        width: 8,
                        height: 24,
                        child: VerticalDivider(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () => _deleteComponent(context, target),
                      ),
                      if (widget.controller.childSelectorBuilder != null)
                        IconButton(
                          icon: Icon(
                            _showAddChild
                                ? Icons.add_circle
                                : Icons.add_circle_outline,
                          ),
                          tooltip: 'Add Child',
                          onPressed: () {
                            setState(() => _showAddChild = !_showAddChild);
                          },
                        ),
                      _buildAssetButton(context, target),
                      if (widget.controller.contextualToolbarBuilder != null)
                        ...widget.controller.contextualToolbarBuilder!(
                          context,
                          target,
                          widget.controller,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showAddChild && widget.controller.childSelectorBuilder != null)
              Positioned(
                left: screenPosition.x + 100,
                top: screenPosition.y - 60,
                child: widget.controller.childSelectorBuilder!(
                  context,
                  target,
                  (childAny) {
                    widget.controller.delegate.onAddChild(target, childAny);
                    setState(() => _showAddChild = false);
                  },
                  () => setState(() => _showAddChild = false),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? colorScheme.primary : colorScheme.onSurface,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? colorScheme.primaryContainer : null,
      ),
    );
  }

  void _deleteComponent(BuildContext context, Component target) {
    widget.controller.delegate.onDeleteComponent(target);
    widget.controller.selectionManager.clear();
  }

  Widget _buildAssetButton(
    BuildContext context,
    PositionComponent target,
  ) {
    final assetDelegate = widget.controller.assetImportDelegate;
    if (assetDelegate == null) return const SizedBox.shrink();

    return assetDelegate.buildAssetButton(context, target) ?? const SizedBox.shrink();
  }
}

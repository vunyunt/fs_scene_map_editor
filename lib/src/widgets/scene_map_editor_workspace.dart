import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../editor_interfaces.dart';
import '../world_editor_controller.dart';
import '../world_editor_selection_manager.dart';
import 'scene_map_inspector.dart';
import 'world_editor_contextual_toolbar.dart';
import 'command_palette.dart';
import '../command_metadata.dart';

class SceneMapEditorWorkspace extends StatefulWidget {
  final String sceneName;
  final SceneMapEditorDelegate delegate;
  final ChildSelectorBuilder? childSelectorBuilder;
  final AssetImportDelegate? assetImportDelegate;
  final ContextualToolbarBuilder? contextualToolbarBuilder;
  final Future<void> Function(WorldEditorController controller) onLoadScene;
  final Future<void> Function() onSave;
  final VoidCallback onDispose;
  final Map<EditorShortcutActivator, EditorControllerAction>? customKeyBindings;
  final List<EditorCommandMetadata>? customCommands;

  const SceneMapEditorWorkspace({
    required this.sceneName,
    required this.delegate,
    required this.onLoadScene,
    required this.onSave,
    required this.onDispose,
    super.key,
    this.childSelectorBuilder,
    this.assetImportDelegate,
    this.contextualToolbarBuilder,
    this.customKeyBindings,
    this.customCommands,
  });

  @override
  State<SceneMapEditorWorkspace> createState() =>
      _SceneMapEditorWorkspaceState();
}

class _SceneMapEditorWorkspaceState extends State<SceneMapEditorWorkspace> {
  late final WorldEditorSelectionManager _selectionManager;
  late final WorldEditorController _editorController;
  bool _isLoaded = false;
  double _inspectorWidth = 350.0;

  @override
  void initState() {
    super.initState();
    _selectionManager = WorldEditorSelectionManager();
    _editorController = WorldEditorController(
      selectionManager: _selectionManager,
      delegate: widget.delegate,
      childSelectorBuilder: widget.childSelectorBuilder,
      assetImportDelegate: widget.assetImportDelegate,
      contextualToolbarBuilder: widget.contextualToolbarBuilder,
      customKeyBindings: widget.customKeyBindings,
      customCommands: widget.customCommands,
    );
    _editorController.commandPaletteRequest.addListener(_onCommandPaletteRequest);

    _loadScene();
  }

  void _onCommandPaletteRequest() {
    if (mounted && _editorController.commandPaletteRequest.value) {
      _editorController.commandPaletteRequest.value = false;
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Command Palette',
        barrierColor: Colors.black.withValues(alpha: 0.5),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, anim1, anim2) {
          return CommandPalette(controller: _editorController);
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: anim1.drive(
              Tween<Offset>(
                begin: const Offset(0.0, -0.1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          );
        },
      );
    }
  }

  Future<void> _loadScene() async {
    await widget.onLoadScene(_editorController);
    _editorController.onSaveRequest = widget.onSave;

    if (mounted) {
      setState(() {
        _isLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _editorController.commandPaletteRequest.removeListener(_onCommandPaletteRequest);
    widget.onDispose();
    _selectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _selectionManager),
      ],
      child: Row(
        children: [
          Expanded(
            child: GameWidgetAdapter(
              controller: _editorController,
              assetImportDelegate: widget.assetImportDelegate,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _inspectorWidth -= details.delta.dx;
                _inspectorWidth = max(100, _inspectorWidth);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                width: 8,
                color: Colors.transparent,
                child: const VerticalDivider(width: 1),
              ),
            ),
          ),
          SizedBox(
            width: _inspectorWidth,
            child: const SceneMapInspector(),
          ),
        ],
      ),
    );
  }
}

class GameWidgetAdapter extends StatefulWidget {
  final WorldEditorController controller;
  final AssetImportDelegate? assetImportDelegate;

  const GameWidgetAdapter({
    super.key,
    required this.controller,
    this.assetImportDelegate,
  });

  @override
  State<GameWidgetAdapter> createState() => _GameWidgetAdapterState();
}

class _GameWidgetAdapterState extends State<GameWidgetAdapter> {
  late final FocusNode _gameFocusNode;

  @override
  void initState() {
    super.initState();
    _gameFocusNode = FocusNode();
    widget.controller.contextMenuRequest.addListener(_onContextMenuRequest);
    widget.controller.selectionManager.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _gameFocusNode.dispose();
    widget.controller.contextMenuRequest.removeListener(_onContextMenuRequest);
    widget.controller.selectionManager.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) {
      final game = context.read<EditorGameHost>();
      if (widget.controller.selectionManager.hasSelection) {
        if (!game.overlays.isActive('ContextualToolbar')) {
          game.overlays.add('ContextualToolbar');
        }
      } else {
        game.overlays.remove('ContextualToolbar');
      }
    }
  }

  void _onContextMenuRequest() {
    if (mounted) {
      if (widget.controller.contextMenuRequest.value != null) {
        final game = context.read<EditorGameHost>();
        game.overlays.add('ContextMenu');
      } else {
        final game = context.read<EditorGameHost>();
        game.overlays.remove('ContextMenu');
      }
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final game = context.read<EditorGameHost>();
    // Convert widget-local position to world position
    final widgetPos = Vector2(
      details.localPosition.dx,
      details.localPosition.dy,
    );
    final screenPos = game.camera.viewport.localToGlobal(widgetPos);
    final worldPos = game.camera.globalToLocal(screenPos);

    if (widget.assetImportDelegate != null) {
      await widget.assetImportDelegate!.onDropDone(context, details, worldPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<EditorGameHost>();
    return ClipRect(
      child: MouseRegion(
        onHover: (event) {
          final widgetPos = Vector2(
            event.localPosition.dx,
            event.localPosition.dy,
          );
          final screenPos = game.camera.viewport.localToGlobal(widgetPos);
          final worldPos = game.camera.globalToLocal(screenPos);
          widget.controller.updateMousePosition(worldPos);
        },
        child: DropTarget(
          onDragDone: _handleDrop,
          child: Listener(
            onPointerDown: (_) => _gameFocusNode.requestFocus(),
            child: GameWidget(
              game: game,
              focusNode: _gameFocusNode,
              overlayBuilderMap: {
                'ContextMenu': (context, game) {
                  return WorldEditorContextMenu(controller: widget.controller);
                },
                'ContextualToolbar': (context, game) {
                  return WorldEditorContextualToolbar(
                    controller: widget.controller,
                  );
                },
              },
            ),
          ),
        ),
      ),
    );
  }
}

class WorldEditorContextMenu extends StatefulWidget {
  final WorldEditorController controller;

  const WorldEditorContextMenu({super.key, required this.controller});

  @override
  State<WorldEditorContextMenu> createState() => _WorldEditorContextMenuState();
}

class _WorldEditorContextMenuState extends State<WorldEditorContextMenu> {
  bool _showSelector = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final event = widget.controller.contextMenuRequest.value;
        if (event == null) return const SizedBox.shrink();

        // Convert local Flame coordinates to global Flutter coordinates
        final game = context.read<EditorGameHost>();
        final position = game.camera.viewport.localToGlobal(
          event.canvasPosition,
        );

        // Clamp position to prevent clipping
        const dialogWidth = 400.0;
        const dialogHeight = 500.0;

        double x = position.x;
        double y = position.y;

        if (x + dialogWidth > constraints.maxWidth) {
          x = constraints.maxWidth - dialogWidth;
        }
        if (y + dialogHeight > constraints.maxHeight) {
          y = constraints.maxHeight - dialogHeight;
        }

        x = x.clamp(0.0, constraints.maxWidth - dialogWidth);
        y = y.clamp(0.0, constraints.maxHeight - dialogHeight);

        return Stack(
          children: [
            GestureDetector(
              onTap: () => widget.controller.contextMenuRequest.value = null,
              behavior: HitTestBehavior.opaque,
              child: Container(),
            ),
            if (!_showSelector)
              Positioned(
                left: position.x,
                top: position.y,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Create New Component'),
                          onTap: () {
                            setState(() => _showSelector = true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showSelector && widget.controller.childSelectorBuilder != null)
              Positioned(
                left: x,
                top: y,
                child: widget.controller.childSelectorBuilder!(
                  context,
                  null,
                  (childAny) {
                    widget.controller.delegate.onCreateComponent(
                      widget.controller.lastSecondaryTapPosition ??
                          Vector2.zero(),
                      childAny,
                    );
                    widget.controller.contextMenuRequest.value = null;
                  },
                  () => widget.controller.contextMenuRequest.value = null,
                ),
              ),
          ],
        );
      },
    );
  }
}

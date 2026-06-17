import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:fs_scene_map/fs_scene_map.dart';

import 'world_editor_selection_manager.dart';
import 'world_editor_command_manager.dart';
import 'selection_gizmo.dart';
import 'world_grid_component.dart';
import 'editor_interfaces.dart';
import 'tools/editor_tool.dart';
import 'tools/move_tool.dart';
import 'tools/rotate_tool.dart';
import 'tools/scale_tool.dart';

class WorldEditorController extends PositionComponent
    with
        TapCallbacks,
        SecondaryTapCallbacks,
        DragCallbacks,
        KeyboardHandler,
        HasGameReference<EditorGameHost> {
  final WorldEditorSelectionManager selectionManager;
  final SceneMapEditorDelegate delegate;
  final ChildSelectorBuilder? childSelectorBuilder;
  final AssetImportDelegate? assetImportDelegate;
  final ContextualToolbarBuilder? contextualToolbarBuilder;
  
  final WorldEditorCommandManager commandManager = WorldEditorCommandManager();
  final Map<Component, SelectionGizmo> _gizmos = {};
  final ValueNotifier<SecondaryTapDownEvent?> contextMenuRequest =
      ValueNotifier(null);
  final ValueNotifier<Type> activeToolType = ValueNotifier(MoveTool);
  Future<void> Function()? onSaveRequest;

  Vector2? lastSecondaryTapPosition;

  bool _isPanning = false;

  EditorTool? _activeTool;
  EditorTool? get activeTool => _activeTool;
  set activeTool(EditorTool? tool) {
    _activeTool?.onDeactivate();
    _activeTool = tool;
    if (tool != null) {
      activeToolType.value = tool.runtimeType;
    }
    _activeTool?.onActivate();
  }

  bool isSimulationRunning = false;

  WorldEditorController({
    required this.selectionManager,
    required this.delegate,
    this.childSelectorBuilder,
    this.assetImportDelegate,
    this.contextualToolbarBuilder,
  }) {
    // The controller should be at a high priority to capture taps,
    // but the gizmos should be even higher.
    priority = 100;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    selectionManager.addListener(_onSelectionChanged);

    // Add grid
    add(WorldGridComponent());

    // Default tool
    activeTool = MoveTool(controller: this, gridSize: 32);

    // Locate SpatialChunkController and enable Edit Mode
    _enableChunkEditMode();
  }

  void _enableChunkEditMode() {
    final spatialController = game.world.spatialChunkController;

    if (spatialController != null) {
      spatialController.isEditMode = true;
    }
  }

  void toggleSimulation() {
    isSimulationRunning = !isSimulationRunning;
  }

  void useMoveTool() {
    activeTool = MoveTool(controller: this, gridSize: 32);
  }

  void useRotateTool() {
    activeTool = RotateTool(controller: this);
  }

  void useScaleTool() {
    activeTool = ScaleTool(controller: this);
  }

  @override
  void onRemove() {
    selectionManager.removeListener(_onSelectionChanged);
    super.onRemove();
  }

  void _onSelectionChanged() {
    final selected = selectionManager.selectedComponents;

    // Remove gizmos for deselected components
    final toRemove = _gizmos.keys.where((c) => !selected.contains(c)).toList();
    for (final c in toRemove) {
      _gizmos[c]?.removeFromParent();
      _gizmos.remove(c);
    }

    // Add gizmos for newly selected components
    for (final c in selected) {
      if (c is PositionComponent && !_gizmos.containsKey(c)) {
        final gizmo = SelectionGizmo(target: c);
        add(gizmo);
        _gizmos[c] = gizmo;
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) => true; // Capture all taps in world space

  @override
  void onTapDown(TapDownEvent event) {
    if (_activeTool != null) {
      _activeTool!.onTapDown(event);
      if (event.handled) return;
    }

    // Default selection logic
    // Find components at the tap location in the world
    final world = game.world;
    final components = world.componentsAtPoint(event.localPosition);

    // Find the first selectable component root
    Component? selectable;
    for (final c in components) {
      final root = _findSelectableRoot(c);
      if (root != null) {
        selectable = root;
        break;
      }
    }

    if (selectable != null) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      if (keys.contains(LogicalKeyboardKey.shiftLeft) ||
          keys.contains(LogicalKeyboardKey.shiftRight)) {
        selectionManager.toggle(selectable);
      } else {
        selectionManager.clear();
        selectionManager.select(selectable);
      }
    } else {
      selectionManager.clear();
    }
  }

  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) {
    lastSecondaryTapPosition = event.localPosition;
    contextMenuRequest.value = event;
  }

  Component? _findSelectableRoot(Component? component) {
    if (component == null) return null;

    Component? current = component;
    Component? lastSelectable;

    while (current != null &&
        current != this &&
        current is! SelectionGizmo &&
        current is! World &&
        current is! BaseSceneMapComponent &&
        current is! SpatialChunkComponent) {
      if (current is ProtoSerializable) {
        lastSelectable = current;
      }
      current = current.parent;
    }

    return lastSelectable;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isSpacePressed = keys.contains(LogicalKeyboardKey.space);

    if (isSpacePressed) {
      _isPanning = true;
      return;
    }

    // Check what is under the cursor at the start of the drag
    final components = game.world.componentsAtPoint(event.localPosition);
    Component? selectable;
    for (final c in components) {
      final root = _findSelectableRoot(c);
      if (root != null) {
        selectable = root;
        break;
      }
    }

    // If nothing selectable is under the cursor, we pan the camera unless the tool captures the drag
    if (selectable == null && !(_activeTool?.captureDragStart(event) ?? false)) {
      _isPanning = true;
      return;
    }

    _activeTool?.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    if (_isPanning) {
      // Pan the camera using canvasDelta (screen pixels) divided by zoom.
      // This is more reliable for camera panning than localDelta.
      final zoom = game.camera.viewfinder.zoom;
      game.camera.viewfinder.position -= event.canvasDelta / zoom;
      return;
    }

    _activeTool?.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_isPanning) {
      _isPanning = false;
    } else {
      _activeTool?.onDragEnd(event);
    }
  }

  Future<void> save() async {
    if (onSaveRequest != null) {
      await onSaveRequest!();
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final isControl =
          keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
          keysPressed.contains(LogicalKeyboardKey.controlRight) ||
          keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
          keysPressed.contains(LogicalKeyboardKey.metaRight);

      if (isControl) {
        if (keysPressed.contains(LogicalKeyboardKey.keyS)) {
          save();
          return true;
        }
        if (keysPressed.contains(LogicalKeyboardKey.keyZ)) {
          if (keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
              keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
            commandManager.redo();
          } else {
            commandManager.undo();
          }
          return true;
        }
        if (keysPressed.contains(LogicalKeyboardKey.keyY)) {
          commandManager.redo();
          return true;
        }
      }
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _activeTool?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _activeTool?.render(canvas);
  }
}

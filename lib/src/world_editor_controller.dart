import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
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

typedef ShortcutActivator = ({
  LogicalKeyboardKey key,
  bool control,
  bool shift,
  bool alt,
});

typedef ControllerAction = bool Function(WorldEditorController controller);

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
  final Set<LogicalKeyboardKey> Function() logicalKeysPressed;

  final WorldEditorCommandManager commandManager = WorldEditorCommandManager();
  final Map<Component, SelectionGizmo> _gizmos = {};
  final ValueNotifier<SecondaryTapDownEvent?> contextMenuRequest =
      ValueNotifier(null);
  final ValueNotifier<Type> activeToolType = ValueNotifier(MoveTool);
  Future<void> Function()? onSaveRequest;

  Vector2? lastSecondaryTapPosition;

  bool _isPanning = false;
  bool _isAreaSelecting = false;
  Vector2? _areaSelectionStart;
  Vector2? _areaSelectionEnd;

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

  Vector2 _mousePosition = Vector2.zero();
  Vector2 get mousePosition => _mousePosition;

  void updateMousePosition(Vector2 pos) {
    _mousePosition = pos;
  }

  static final List<Any> _clipboard = [];

  void copySelection() {
    _clipboard.clear();
    for (final component in selectionManager.selectedComponents) {
      if (component is ProtoSerializable) {
        _clipboard.add(Any.pack((component as ProtoSerializable).serialize()));
      }
    }
  }

  void paste() {
    if (_clipboard.isEmpty) return;
    for (final any in _clipboard) {
      delegate.onPaste(_mousePosition, any);
    }
  }

  static final Map<ShortcutActivator, ControllerAction> defaultKeyBindings = {
    (key: LogicalKeyboardKey.keyS, control: true, shift: false, alt: false): (c) {
      c.save();
      return true;
    },
    (key: LogicalKeyboardKey.keyC, control: true, shift: false, alt: false): (c) {
      c.copySelection();
      return true;
    },
    (key: LogicalKeyboardKey.keyV, control: true, shift: false, alt: false): (c) {
      c.paste();
      return true;
    },
    (key: LogicalKeyboardKey.keyZ, control: true, shift: false, alt: false): (c) {
      c.commandManager.undo();
      return true;
    },
    (key: LogicalKeyboardKey.keyZ, control: true, shift: true, alt: false): (c) {
      c.commandManager.redo();
      return true;
    },
    (key: LogicalKeyboardKey.keyY, control: true, shift: false, alt: false): (c) {
      c.commandManager.redo();
      return true;
    },
    (key: LogicalKeyboardKey.tab, control: false, shift: false, alt: false): (c) {
      c.selectionManager.togglePrimaryForward();
      return c.selectionManager.hasSelection;
    },
    (key: LogicalKeyboardKey.delete, control: false, shift: false, alt: false): (c) {
      final selected = c.selectionManager.selectedComponents.toList();
      if (selected.isNotEmpty) {
        for (final component in selected) {
          c.delegate.onDeleteComponent(component);
        }
        c.selectionManager.clear();
        return true;
      }
      return false;
    },
  };

  final Map<ShortcutActivator, ControllerAction> _keyBindings;

  WorldEditorController({
    required this.selectionManager,
    required this.delegate,
    this.childSelectorBuilder,
    this.assetImportDelegate,
    this.contextualToolbarBuilder,
    Set<LogicalKeyboardKey> Function()? logicalKeysPressed,
    Map<ShortcutActivator, ControllerAction>? customKeyBindings,
  }) : logicalKeysPressed =
           logicalKeysPressed ??
           (() => HardwareKeyboard.instance.logicalKeysPressed),
       _keyBindings = {
         ...defaultKeyBindings,
         ...?customKeyBindings,
       } {
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
        final gizmo = SelectionGizmo(
          target: c,
          isPrimary: () => selectionManager.primarySelection == c,
        );
        add(gizmo);
        _gizmos[c] = gizmo;
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) => true; // Capture all taps in world space

  bool _isPanModifierPressed(Set<LogicalKeyboardKey> keys) {
    return keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isPanModifierPressed(logicalKeysPressed())) {
      return;
    }

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
      final keys = logicalKeysPressed();
      if (_isMultiSelectModifierPressed(keys)) {
        selectionManager.toggle(selectable);
      } else if (selectionManager.isSelected(selectable)) {
        selectionManager.setPrimary(selectable);
      } else {
        selectionManager.selectOnly(selectable);
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

    final keys = logicalKeysPressed();
    final isSpacePressed = keys.contains(LogicalKeyboardKey.space);

    if (isSpacePressed || _isPanModifierPressed(keys)) {
      _isPanning = true;
      return;
    }

    final isMultiSelect = _isMultiSelectModifierPressed(keys);

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

    final activeToolCapturesDrag =
        _activeTool?.captureDragStart(event) ?? false;

    if (selectable == null && !activeToolCapturesDrag) {
      _isAreaSelecting = true;
      _areaSelectionStart = event.localPosition.clone();
      _areaSelectionEnd = event.localPosition.clone();
      if (!isMultiSelect) {
        selectionManager.clear();
      }
      return;
    }

    if (isMultiSelect && selectable != null) {
      selectionManager.toggle(selectable);
      event.handled = true;
      return;
    }

    if (selectable != null && !selectionManager.isSelected(selectable)) {
      selectionManager.selectOnly(selectable);
    } else if (selectable != null) {
      selectionManager.setPrimary(selectable);
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

    if (_isAreaSelecting) {
      _areaSelectionEnd = (_areaSelectionEnd ?? _areaSelectionStart)?.clone()
        ?..add(event.localDelta);
      return;
    }

    _activeTool?.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_isPanning) {
      _isPanning = false;
    } else if (_isAreaSelecting) {
      _selectComponentsInArea();
      _isAreaSelecting = false;
      _areaSelectionStart = null;
      _areaSelectionEnd = null;
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
      final ctrl = keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
          keysPressed.contains(LogicalKeyboardKey.controlRight) ||
          keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
          keysPressed.contains(LogicalKeyboardKey.metaRight);
      final shift = keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          keysPressed.contains(LogicalKeyboardKey.shiftRight);
      final alt = keysPressed.contains(LogicalKeyboardKey.altLeft) ||
          keysPressed.contains(LogicalKeyboardKey.altRight);

      final pressedShortcut = (
        key: event.logicalKey,
        control: ctrl,
        shift: shift,
        alt: alt,
      );

      final action = _keyBindings[pressedShortcut];
      if (action != null) {
        return action(this);
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
    _renderAreaSelection(canvas);
  }

  bool _isMultiSelectModifierPressed(Set<LogicalKeyboardKey> keys) {
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  void _selectComponentsInArea() {
    final rect = _areaSelectionRect;
    if (rect == null) return;

    final existing = selectionManager.selectedComponents.toList();
    final selected = <Component>[
      if (_isMultiSelectModifierPressed(logicalKeysPressed())) ...existing,
    ];

    for (final component in _selectableComponentsIn(game.world)) {
      if (component is! PositionComponent) continue;
      if (!_componentIntersectsRect(component, rect)) continue;
      if (!selected.contains(component)) {
        selected.add(component);
      }
    }

    selectionManager.selectAll(selected);
  }

  Iterable<Component> _selectableComponentsIn(Component root) sync* {
    for (final child in root.children) {
      final selectable = _findSelectableRoot(child);
      if (selectable == child) {
        yield child;
      }
      yield* _selectableComponentsIn(child);
    }
  }

  bool _componentIntersectsRect(PositionComponent component, Rect rect) {
    final corners = [
      Vector2.zero(),
      Vector2(component.size.x, 0),
      component.size,
      Vector2(0, component.size.y),
    ].map(component.absolutePositionOf).toList();

    final xs = corners.map((corner) => corner.x);
    final ys = corners.map((corner) => corner.y);
    final bounds = Rect.fromLTRB(
      xs.reduce((a, b) => a < b ? a : b),
      ys.reduce((a, b) => a < b ? a : b),
      xs.reduce((a, b) => a > b ? a : b),
      ys.reduce((a, b) => a > b ? a : b),
    );

    return bounds.overlaps(rect) || rect.contains(bounds.center);
  }

  Rect? get _areaSelectionRect {
    final start = _areaSelectionStart;
    final end = _areaSelectionEnd;
    if (start == null || end == null) return null;

    return Rect.fromLTRB(
      start.x < end.x ? start.x : end.x,
      start.y < end.y ? start.y : end.y,
      start.x > end.x ? start.x : end.x,
      start.y > end.y ? start.y : end.y,
    );
  }

  void _renderAreaSelection(Canvas canvas) {
    final rect = _areaSelectionRect;
    if (!_isAreaSelecting || rect == null) return;

    final fill = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }
}

import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:protobuf_serializable_components/protobuf_serializable_components.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
import 'package:fs_scene_map/fs_scene_map.dart';
import 'command_metadata.dart';

import 'world_editor_selection_manager.dart';
import 'world_editor_command_manager.dart';
import 'selection_gizmo.dart';
import 'world_grid_component.dart';
import 'editor_interfaces.dart';
import 'tools/editor_tool.dart';
import 'tools/move_tool.dart';
import 'tools/rotate_tool.dart';
import 'tools/scale_tool.dart';

typedef EditorShortcutActivator = ({
  LogicalKeyboardKey key,
  bool control,
  bool shift,
  bool alt,
});

typedef EditorControllerAction = bool Function(WorldEditorController controller);

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
  final ValueNotifier<bool> commandPaletteRequest = ValueNotifier(false);
  final ValueNotifier<String> commandPalettePrefix = ValueNotifier('>');
  final List<EditorCommandMetadata> customCommands;
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

  late final Map<EditorShortcutActivator, EditorControllerAction> _keyBindings;

  WorldEditorController({
    required this.selectionManager,
    required this.delegate,
    this.childSelectorBuilder,
    this.assetImportDelegate,
    this.contextualToolbarBuilder,
    Set<LogicalKeyboardKey> Function()? logicalKeysPressed,
    Map<EditorShortcutActivator, EditorControllerAction>? customKeyBindings,
    List<EditorCommandMetadata>? customCommands,
  }) : logicalKeysPressed =
            logicalKeysPressed ??
            (() => HardwareKeyboard.instance.logicalKeysPressed),
        customCommands = customCommands ?? const [] {
    // The controller should be at a high priority to capture taps,
    // but the gizmos should be even higher.
    priority = 100;

    // Derive the key bindings from the single source of truth: the command
    // metadata. Each command may expose one or more shortcut activators that
    // all dispatch to the same action. Caller-supplied customKeyBindings are
    // applied last so they can override or extend the built-in bindings.
    _keyBindings = {
      for (final command in allCommands)
        for (final shortcut in command.shortcuts)
          shortcut: command.action,
      ...?customKeyBindings,
    };
  }

  List<EditorCommandMetadata> get builtInCommands => [
        EditorCommandMetadata(
          id: 'save',
          label: 'Save Scene',
          description: 'Save all current scene modifications',
          shortcutText: 'Ctrl+S',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyS, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.save();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'copy',
          label: 'Copy Selection',
          description: 'Copy selected components to clipboard',
          shortcutText: 'Ctrl+C',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyC, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.copySelection();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'paste',
          label: 'Paste',
          description: 'Paste components from clipboard at mouse position',
          shortcutText: 'Ctrl+V',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyV, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.paste();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'undo',
          label: 'Undo Action',
          description: 'Undo the last action',
          shortcutText: 'Ctrl+Z',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyZ, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.commandManager.undo();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'redo',
          label: 'Redo Action',
          description: 'Redo the last undone action',
          shortcutText: 'Ctrl+Shift+Z',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyZ, control: true, shift: true, alt: false),
            (key: LogicalKeyboardKey.keyY, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.commandManager.redo();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'delete',
          label: 'Delete Selection',
          description: 'Delete all selected components',
          shortcutText: 'Delete',
          shortcuts: const [
            (key: LogicalKeyboardKey.delete, control: false, shift: false, alt: false),
          ],
          action: (c) {
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
        ),
        EditorCommandMetadata(
          id: 'clear_selection',
          label: 'Clear Selection',
          description: 'Deselect all components',
          shortcutText: 'Escape',
          shortcuts: const [
            (key: LogicalKeyboardKey.escape, control: false, shift: false, alt: false),
          ],
          action: (c) {
            if (c.selectionManager.hasSelection) {
              c.selectionManager.clear();
              return true;
            }
            return false;
          },
        ),
        EditorCommandMetadata(
          id: 'focus_selection',
          label: 'Focus Selection',
          description: 'Center viewfinder on selected components',
          shortcutText: 'F',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyF, control: false, shift: false, alt: false),
          ],
          action: (c) {
            c.focusSelection();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'duplicate',
          label: 'Duplicate Selection',
          description: 'Duplicate selected components',
          shortcutText: 'Ctrl+D',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyD, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.duplicateSelection();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'group',
          label: 'Group Selection',
          description: 'Group selected components into a parent component',
          shortcutText: 'Ctrl+G',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyG, control: true, shift: false, alt: false),
          ],
          action: (c) => c.groupSelection(),
        ),
        EditorCommandMetadata(
          id: 'ungroup',
          label: 'Ungroup Selection',
          description: 'Ungroup children from the selected group component',
          shortcutText: 'Ctrl+Shift+G',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyG, control: true, shift: true, alt: false),
          ],
          action: (c) => c.ungroupSelection(),
        ),
        EditorCommandMetadata(
          id: 'zoom_in',
          label: 'Zoom In',
          description: 'Zoom viewfinder in',
          shortcutText: 'Ctrl++',
          shortcuts: const [
            (key: LogicalKeyboardKey.equal, control: true, shift: false, alt: false),
            (key: LogicalKeyboardKey.numpadAdd, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.zoomIn();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'zoom_out',
          label: 'Zoom Out',
          description: 'Zoom viewfinder out',
          shortcutText: 'Ctrl+-',
          shortcuts: const [
            (key: LogicalKeyboardKey.minus, control: true, shift: false, alt: false),
            (key: LogicalKeyboardKey.numpadSubtract, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.zoomOut();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'zoom_reset',
          label: 'Reset Zoom',
          description: 'Reset zoom level to default (1.0)',
          shortcutText: 'Ctrl+0',
          shortcuts: const [
            (key: LogicalKeyboardKey.digit0, control: true, shift: false, alt: false),
            (key: LogicalKeyboardKey.numpad0, control: true, shift: false, alt: false),
          ],
          action: (c) {
            c.resetZoom();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'tool_move',
          label: 'Move Tool',
          description: 'Switch to the move tool',
          shortcutText: '1',
          shortcuts: const [
            (key: LogicalKeyboardKey.digit1, control: false, shift: false, alt: false),
          ],
          action: (c) {
            c.useMoveTool();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'tool_rotate',
          label: 'Rotate Tool',
          description: 'Switch to the rotate tool',
          shortcutText: '2',
          shortcuts: const [
            (key: LogicalKeyboardKey.digit2, control: false, shift: false, alt: false),
          ],
          action: (c) {
            c.useRotateTool();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'tool_scale',
          label: 'Scale Tool',
          description: 'Switch to the scale tool',
          shortcutText: '3',
          shortcuts: const [
            (key: LogicalKeyboardKey.digit3, control: false, shift: false, alt: false),
          ],
          action: (c) {
            c.useScaleTool();
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'command_palette',
          label: 'Show Command Palette',
          description: 'Open the command palette',
          shortcutText: 'Ctrl+Shift+P',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyP, control: true, shift: true, alt: false),
          ],
          action: (c) {
            c.commandPalettePrefix.value = '>';
            c.commandPaletteRequest.value = true;
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'add_component_palette',
          label: 'Add Component...',
          description: 'Open the command palette in add component mode',
          shortcutText: 'Ctrl+Shift+I / Shift+A',
          shortcuts: const [
            (key: LogicalKeyboardKey.keyI, control: true, shift: true, alt: false),
            (key: LogicalKeyboardKey.keyA, control: false, shift: true, alt: false),
          ],
          action: (c) {
            c.commandPalettePrefix.value = '+';
            c.commandPaletteRequest.value = true;
            return true;
          },
        ),
        EditorCommandMetadata(
          id: 'cycle_selection',
          label: 'Cycle Primary Selection',
          description: 'Toggle primary selection forward through selected components',
          shortcutText: 'Tab',
          shortcuts: const [
            (key: LogicalKeyboardKey.tab, control: false, shift: false, alt: false),
          ],
          showInPalette: false,
          action: (c) {
            c.selectionManager.togglePrimaryForward();
            return c.selectionManager.hasSelection;
          },
        ),
      ];

  List<EditorCommandMetadata> get allCommands => [
        ...builtInCommands,
        ...customCommands,
      ];

  List<EditorCommandMetadata> get paletteComponentCommands {
    final registry = game.serializableComponentRegistry;
    final commands = <EditorCommandMetadata>[];
    for (final name in registry.registeredQualifiedNames) {
      final descriptor = registry.getDescriptor(name);
      final meta = descriptor?.meta;
      if (meta is PaletteComponentMeta) {
        final paletteMeta = meta as PaletteComponentMeta;
        if (paletteMeta.showInPalette) {
          commands.add(
            AddComponentCommandMetadata(
              id: 'add_component_$name',
              label: paletteMeta.paletteLabel ?? game.getComponentName(descriptor!.defaultInstance),
              description: paletteMeta.paletteDescription ?? game.getComponentShortDescription(descriptor!.defaultInstance),
              descriptor: descriptor!,
              showInPalette: true,
            ),
          );
        }
      }
    }
    // Sort commands alphabetically by label
    commands.sort((a, b) => a.label.compareTo(b.label));
    return commands;
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

  void duplicateSelection() {
    final selected = selectionManager.selectedComponents.toList();
    if (selected.isEmpty) return;
    for (final component in selected) {
      if (component is ProtoSerializable) {
        final any = Any.pack((component as ProtoSerializable).serialize());
        final pos = component is PositionComponent
            ? component.absolutePosition + Vector2(32, 32)
            : _mousePosition;
        delegate.onPaste(pos, any);
      }
    }
  }

  /// Groups the currently selected positioned components into a new container.
  /// Requires at least two selected [PositionComponent]s.
  bool groupSelection() {
    final selected = selectionManager.selectedComponents
        .whereType<PositionComponent>()
        .toList();
    if (selected.length < 2) return false;
    delegate.onGroup(selected);
    return true;
  }

  /// Ungroups each selected positioned component that has children, reparenting
  /// its children to the component's current parent.
  bool ungroupSelection() {
    final selected = selectionManager.selectedComponents
        .whereType<PositionComponent>()
        .toList();
    if (selected.isEmpty) return false;
    delegate.onUngroup(selected.first);
    return true;
  }

  void focusSelection() {
    final selected = selectionManager.selectedComponents.whereType<PositionComponent>();
    if (selected.isEmpty) return;

    final center = Vector2.zero();
    for (final component in selected) {
      center.add(component.absolutePosition);
    }
    center.scale(1.0 / selected.length);

    game.camera.viewfinder.position = center;
  }

  void zoomIn() {
    game.camera.viewfinder.zoom = (game.camera.viewfinder.zoom * 1.2).clamp(0.1, 10.0);
  }

  void zoomOut() {
    game.camera.viewfinder.zoom = (game.camera.viewfinder.zoom / 1.2).clamp(0.1, 10.0);
  }

  void resetZoom() {
    game.camera.viewfinder.zoom = 1.0;
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

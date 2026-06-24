# Command Palette System

The World Map Editor features a searchable, keystroke-driven **Command Palette** widget (`CommandPalette`) designed to improve developer efficiency. The palette supports two distinct modes, differentiated by the leading character prefix:
1.  **Command Mode (`>`)**: Allows searching and executing editor commands (e.g., Save Scene, switch tools, group components).
2.  **Add Component Mode (`+`)**: Allows searching and adding curated game-specific components directly to the scene map.

---

## 1. System Architecture

The palette relies on a polymorphic design that keeps the core serialization libraries completely decoupled from editor-specific concepts.

```mermaid
graph TD
    subgraph protobuf_serializable_components (Core)
        A[ProtoComponentMeta]
    end
    subgraph fs_scene_map_editor (Editor Package)
        B[PaletteComponentMeta] -->|extends/implements| A
        C[WorldEditorController] -->|queries registry| A
        C -->|checks if meta is| B
        C -->|creates| D[EditorCommandMetadata]
        E[CommandPalette] -->|renders| D
    end
    subgraph game_project (Game Implementation)
        F[SpriteDisplayMeta] -->|implements| B
    end
```

### Decoupled Polymorphism
*   **Core Registry**: Components are registered in `SerializableComponentRegistry` using `ComponentDescriptor` (generated automatically via `build_runner`). The descriptor holds a generic `ProtoComponentMeta` instance.
*   **Editor-specific Metadata Interface**: The editor package defines the `PaletteComponentMeta` interface in `fs_scene_map_editor`.
*   **Polymorphic Query**: At runtime, `WorldEditorController` queries the registry. If a component's metadata class implements `PaletteComponentMeta`, it is dynamically mapped to a component creation action and made available in the `+` prefix search results.

---

## 2. Command Palette Modes

### Command Mode (`>`)
*   **Prefix**: `>`
*   **Triggers**: `Ctrl + Shift + P`
*   **Hint**: `Type to search commands...`
*   **Source**: `controller.allCommands` (merging built-in editor commands and project-supplied custom commands).

### Add Component Mode (`+`)
*   **Prefix**: `+`
*   **Triggers**: `Ctrl + Shift + I` or `Shift + A` (Blender standard)
*   **Hint**: `Type to search components to add...`
*   **Source**: `controller.paletteComponentCommands` (curated from components implementing `PaletteComponentMeta` with `showInPalette = true`).
*   **Placement Behavior**: Spawns the chosen component at the current viewfinder center.

---

## 3. How to Register a Component for the Palette

To make a game component selectable in the Add Component mode, the game's component metadata class (typically found in `.scp.dart` files) must implement `PaletteComponentMeta` and override the required getters.

### Example:
```dart
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';
import 'package:frogsoup_model/frogsoup_model.dart';
import 'package:flutter/material.dart';

class SpriteDisplayMeta extends ProtoComponentMeta<SpriteDisplayProto>
    implements PaletteComponentMeta {
  const SpriteDisplayMeta();

  // 1. Opt into the command palette
  @override
  bool get showInPalette => true;

  // 2. Specify human-readable label shown in the palette
  @override
  String? get paletteLabel => 'Sprite Display';

  // 3. Provide a brief description of what the component does
  @override
  String? get paletteDescription => 'Displays a static sprite image';

  // 4. Optionally group components by category
  @override
  String get paletteCategory => 'Display';

  @override
  IconData? getIcon(SpriteDisplayProto data) => Icons.image;
  
  ...
}
```

---

## 4. Key Bindings & Shortcut Registration

Shortcuts are managed by the `WorldEditorController` using its built-in key binding registry. When a shortcut is triggered, it configures the correct prefix and toggles the `commandPaletteRequest` ValueNotifier:

*   **`Ctrl + Shift + P`**: Sets `commandPalettePrefix.value = '>'` and requests the palette dialog.
*   **`Ctrl + Shift + I`**: Sets `commandPalettePrefix.value = '+'` and requests the palette dialog.
*   **`Shift + A`**: Sets `commandPalettePrefix.value = '+'` and requests the palette dialog.

### Prefix Switching and Formatting
*   Users can switch modes seamlessly inside the palette text box by deleting the prefix and typing the other one (e.g. replacing `>` with `+`).
*   The `_KeepCommandPrefixFormatter` ensures the prefix is never fully deleted by backspaces; instead, it preserves the previously active prefix if the user deletes back to index 0, preventing accidental closure of search scopes.

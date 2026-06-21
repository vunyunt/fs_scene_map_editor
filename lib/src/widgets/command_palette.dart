import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world_editor_controller.dart';
import '../command_metadata.dart';

class CommandPalette extends StatefulWidget {
  final WorldEditorController controller;

  const CommandPalette({super.key, required this.controller});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final TextEditingController _textController;
  late final FocusNode _textFieldFocusNode;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<EditorCommandMetadata> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate with '>' prefix as requested
    _textController = TextEditingController(text: '>');
    // Place the cursor after the '>' so typing appends rather than replacing.
    _textController.selection = const TextSelection.collapsed(offset: 1);
    _textFieldFocusNode = FocusNode();
    _textFieldFocusNode.addListener(_onTextFieldFocusChanged);
    _textController.addListener(_onQueryChanged);
    _updateFilteredCommands();
    // Ensure the text field receives focus when the palette opens.
    // autofocus on TextField is unreliable inside showGeneralDialog due to
    // timing, so we explicitly request focus after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFieldFocusNode.requestFocus();
      }
    });
  }

  void _onTextFieldFocusChanged() {
    if (_textFieldFocusNode.hasFocus) {
      // When the field gains focus, Flutter's default behavior selects the
      // full text, which would cause typing to replace the '>' prefix.
      // Move the cursor to the end (after the prefix and any existing text)
      // with no selection. Defer to the next frame so Flutter's internal
      // focus handling settles first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textFieldFocusNode.hasFocus) {
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.removeListener(_onTextFieldFocusChanged);
    _textFieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _updateFilteredCommands();
    });
  }

  void _updateFilteredCommands() {
    final rawQuery = _textController.text;
    if (!rawQuery.startsWith('>')) {
      _filteredCommands = [];
      _selectedIndex = 0;
      return;
    }

    final query = rawQuery.substring(1).trim().toLowerCase();
    final all = widget.controller.allCommands.where((cmd) => cmd.showInPalette).toList();

    if (query.isEmpty) {
      _filteredCommands = all;
    } else {
      _filteredCommands = all.where((cmd) {
        return cmd.label.toLowerCase().contains(query) ||
            cmd.description.toLowerCase().contains(query);
      }).toList();
    }

    if (_filteredCommands.isEmpty) {
      _selectedIndex = 0;
    } else {
      _selectedIndex = _selectedIndex.clamp(0, _filteredCommands.length - 1);
    }
  }

  void _executeCommand(EditorCommandMetadata command) {
    Navigator.of(context).pop();
    command.action(widget.controller);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = index * itemHeight;

    if (targetOffset < _scrollController.offset) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight > _scrollController.offset + viewportHeight) {
      _scrollController.animateTo(
        targetOffset + itemHeight - viewportHeight,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawQuery = _textController.text;
    final isCommandMode = rawQuery.startsWith('>');

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_filteredCommands.isNotEmpty) {
              setState(() {
                _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
              });
              _scrollToIndex(_selectedIndex);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_filteredCommands.isNotEmpty) {
              setState(() {
                _selectedIndex =
                    (_selectedIndex - 1 + _filteredCommands.length) %
                        _filteredCommands.length;
              });
              _scrollToIndex(_selectedIndex);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (_filteredCommands.isNotEmpty &&
                _selectedIndex >= 0 &&
                _selectedIndex < _filteredCommands.length) {
              _executeCommand(_filteredCommands[_selectedIndex]);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 600,
            margin: const EdgeInsets.only(top: 80, bottom: 80),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Slate 900
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x3338BDF8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input field
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFieldFocusNode,
                    inputFormatters: [_KeepCommandPrefixFormatter()],
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type to search commands...',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B), // Slate 800
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF38BDF8), // Cyan
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0x22FFFFFF),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const Divider(color: Color(0x22FFFFFF), height: 1),
                // Results or instruction helper
                Flexible(
                  child: !isCommandMode
                      ? _buildModeHelper()
                      : _filteredCommands.isEmpty
                          ? _buildNoResults()
                          : _buildCommandsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeHelper() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 18),
          SizedBox(width: 8),
          Text(
            "Type '>' to search map editor commands",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.center,
      child: const Text(
        'No matching commands found.',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCommandsList() {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: _filteredCommands.length,
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      itemBuilder: (context, index) {
        final command = _filteredCommands[index];
        final isSelected = index == _selectedIndex;

        return InkWell(
          onTap: () => _executeCommand(command),
          hoverColor: const Color(0x0D38BDF8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0x1A38BDF8) : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Command label & description on the left
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        command.label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        command.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Shortcut badge on the right
                if (command.shortcutText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0x2638BDF8) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? const Color(0x4D38BDF8) : const Color(0x11FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      command.shortcutText,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ensures the command palette text always begins with the '>' prefix.
///
/// For now the prefix is mandatory and is re-added if the user backspaces
/// over it or replaces the entire field contents. In the future, when other
/// (non-command) palette modes are introduced, this restriction will be
/// lifted so users can delete the prefix to switch modes.
class _KeepCommandPrefixFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith('>')) {
      return newValue;
    }
    final text = '>${newValue.text}';
    final base = newValue.selection.baseOffset < 0
        ? text.length
        : _clampOffset(newValue.selection.baseOffset + 1, text.length);
    final extent = newValue.selection.extentOffset < 0
        ? text.length
        : _clampOffset(newValue.selection.extentOffset + 1, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
  }

  static int _clampOffset(int value, int max) {
    if (value < 1) return 1;
    if (value > max) return max;
    return value;
  }
}

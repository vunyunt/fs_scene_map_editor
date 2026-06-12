import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'commands/editor_command.dart';

class WorldEditorCommandManager extends ChangeNotifier {
  final ListQueue<EditorCommand> _undoStack = ListQueue();
  final ListQueue<EditorCommand> _redoStack = ListQueue();

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void execute(EditorCommand command) {
    command.execute();
    _undoStack.addLast(command);
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.addLast(command);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.addLast(command);
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

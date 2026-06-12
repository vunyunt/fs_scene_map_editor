import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

class WorldEditorSelectionManager extends ChangeNotifier {
  final Set<Component> _selectedComponents = {};

  Set<Component> get selectedComponents =>
      Set.unmodifiable(_selectedComponents);

  bool get hasSelection => _selectedComponents.isNotEmpty;

  void select(Component component) {
    if (_selectedComponents.contains(component)) return;
    _selectedComponents.add(component);
    notifyListeners();
  }

  void deselect(Component component) {
    if (!_selectedComponents.contains(component)) return;
    _selectedComponents.remove(component);
    notifyListeners();
  }

  void toggle(Component component) {
    if (_selectedComponents.contains(component)) {
      _selectedComponents.remove(component);
    } else {
      _selectedComponents.add(component);
    }
    notifyListeners();
  }

  void clear() {
    if (_selectedComponents.isEmpty) return;
    _selectedComponents.clear();
    notifyListeners();
  }

  bool isSelected(Component component) =>
      _selectedComponents.contains(component);
}

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

class WorldEditorSelectionManager extends ChangeNotifier {
  final Set<Component> _selectedComponents = {};
  Component? _primarySelection;

  Set<Component> get selectedComponents =>
      Set.unmodifiable(_selectedComponents);

  Component? get primarySelection => _primarySelection;

  bool get hasSelection => _selectedComponents.isNotEmpty;

  void select(Component component) {
    if (_selectedComponents.contains(component)) {
      if (_primarySelection == component) return;
      _primarySelection = component;
      notifyListeners();
      return;
    }
    _selectedComponents.add(component);
    _primarySelection = component;
    notifyListeners();
  }

  void selectOnly(Component component) {
    if (_selectedComponents.length == 1 &&
        _selectedComponents.contains(component) &&
        _primarySelection == component) {
      return;
    }

    _selectedComponents
      ..clear()
      ..add(component);
    _primarySelection = component;
    notifyListeners();
  }

  void selectAll(Iterable<Component> components, {Component? primary}) {
    final next = components.toList();
    final nextSet = next.toSet();
    final nextPrimary = primary != null && nextSet.contains(primary)
        ? primary
        : _firstOrNull(next);

    if (setEquals(_selectedComponents, nextSet) &&
        _primarySelection == nextPrimary) {
      return;
    }

    _selectedComponents
      ..clear()
      ..addAll(next);
    _primarySelection = nextPrimary;
    notifyListeners();
  }

  void setPrimary(Component component) {
    if (!_selectedComponents.contains(component)) return;
    if (_primarySelection == component) return;
    _primarySelection = component;
    notifyListeners();
  }

  void deselect(Component component) {
    if (!_selectedComponents.contains(component)) return;
    _selectedComponents.remove(component);
    if (_primarySelection == component) {
      _primarySelection = _firstOrNull(_selectedComponents);
    }
    notifyListeners();
  }

  void toggle(Component component) {
    if (_selectedComponents.contains(component)) {
      _selectedComponents.remove(component);
      if (_primarySelection == component) {
        _primarySelection = _firstOrNull(_selectedComponents);
      }
    } else {
      _selectedComponents.add(component);
      _primarySelection = component;
    }
    notifyListeners();
  }

  void togglePrimaryForward() {
    if (_selectedComponents.length < 2) return;

    final selected = _selectedComponents.toList();
    final currentIndex = _primarySelection == null
        ? -1
        : selected.indexOf(_primarySelection!);
    final nextIndex = (currentIndex + 1) % selected.length;
    _primarySelection = selected[nextIndex];
    notifyListeners();
  }

  void clear() {
    if (_selectedComponents.isEmpty) return;
    _selectedComponents.clear();
    _primarySelection = null;
    notifyListeners();
  }

  bool isSelected(Component component) =>
      _selectedComponents.contains(component);

  Component? _firstOrNull(Iterable<Component> components) {
    final iterator = components.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

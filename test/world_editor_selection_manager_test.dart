import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_scene_map_editor/fs_scene_map_editor.dart';

void main() {
  group('WorldEditorSelectionManager', () {
    test('select adds component to set', () {
      final manager = WorldEditorSelectionManager();
      final component = Component();

      manager.select(component);

      expect(manager.selectedComponents, contains(component));
      expect(manager.primarySelection, component);
      expect(manager.hasSelection, isTrue);
    });

    test('selectOnly replaces previous selection and primary', () {
      final manager = WorldEditorSelectionManager();
      final c1 = Component();
      final c2 = Component();

      manager.select(c1);
      manager.selectOnly(c2);

      expect(manager.selectedComponents, {c2});
      expect(manager.primarySelection, c2);
    });

    test('deselect removes component from set', () {
      final manager = WorldEditorSelectionManager();
      final component = Component();

      manager.select(component);
      manager.deselect(component);

      expect(manager.selectedComponents, isEmpty);
      expect(manager.primarySelection, isNull);
      expect(manager.hasSelection, isFalse);
    });

    test('clear removes all components', () {
      final manager = WorldEditorSelectionManager();
      final c1 = Component();
      final c2 = Component();

      manager.select(c1);
      manager.select(c2);
      manager.clear();

      expect(manager.selectedComponents, isEmpty);
      expect(manager.primarySelection, isNull);
    });

    test('toggle adds or removes component', () {
      final manager = WorldEditorSelectionManager();
      final component = Component();

      manager.toggle(component);
      expect(manager.isSelected(component), isTrue);
      expect(manager.primarySelection, component);

      manager.toggle(component);
      expect(manager.isSelected(component), isFalse);
      expect(manager.primarySelection, isNull);
    });

    test('setPrimary updates primary within multi-selection', () {
      final manager = WorldEditorSelectionManager();
      final c1 = Component();
      final c2 = Component();

      manager.select(c1);
      manager.select(c2);
      manager.setPrimary(c1);

      expect(manager.selectedComponents, containsAll([c1, c2]));
      expect(manager.primarySelection, c1);
    });

    test('togglePrimaryForward cycles primary selection', () {
      final manager = WorldEditorSelectionManager();
      final c1 = Component();
      final c2 = Component();
      final c3 = Component();

      manager.selectAll([c1, c2, c3], primary: c1);

      manager.togglePrimaryForward();
      expect(manager.primarySelection, c2);

      manager.togglePrimaryForward();
      expect(manager.primarySelection, c3);

      manager.togglePrimaryForward();
      expect(manager.primarySelection, c1);
    });

    test('notifies listeners on change', () {
      final manager = WorldEditorSelectionManager();
      final component = Component();
      int callCount = 0;
      manager.addListener(() => callCount++);

      manager.select(component);
      expect(callCount, 1);

      manager.deselect(component);
      expect(callCount, 2);

      manager.clear();
      expect(callCount, 2);
    });
  });
}

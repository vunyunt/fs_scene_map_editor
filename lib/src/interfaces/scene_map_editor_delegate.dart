import 'package:flame/components.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';

abstract class SceneMapEditorDelegate {
  void updatePosition(PositionComponent component, Vector2 position);
  void updateScale(PositionComponent component, Vector2 scale);
  void updateAngle(PositionComponent component, double angle);

  void onDeleteComponent(Component component);
  void onAddChild(PositionComponent parent, Any childAny);
  void onCreateComponent(Vector2 worldPos, Any childAny);
  void onPaste(Vector2 worldPos, Any childAny) {}
}

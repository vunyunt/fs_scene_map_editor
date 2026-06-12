import 'package:flame/components.dart';

class SnappingUtils {
  static double snap(double value, double gridSize) {
    if (gridSize <= 0) return value;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  static Vector2 snapVector(Vector2 vector, double gridSize) {
    if (gridSize <= 0) return vector;
    return Vector2(snap(vector.x, gridSize), snap(vector.y, gridSize));
  }
}

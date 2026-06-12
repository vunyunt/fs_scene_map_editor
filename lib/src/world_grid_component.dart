import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class WorldGridComponent extends Component with HasGameReference<FlameGame> {
  final double gridSize;
  final Color gridColor;
  final double strokeWidth;

  WorldGridComponent({
    this.gridSize = 32.0,
    this.gridColor = const Color(0x33FFFFFF),
    this.strokeWidth = 1.0,
  }) {
    // Should be at the bottom
    priority = -1000;
  }

  @override
  void render(Canvas canvas) {
    final visibleRect = game.camera.visibleWorldRect;

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final startX = (visibleRect.left / gridSize).floor() * gridSize;
    final endX = (visibleRect.right / gridSize).ceil() * gridSize;
    final startY = (visibleRect.top / gridSize).floor() * gridSize;
    final endY = (visibleRect.bottom / gridSize).ceil() * gridSize;

    for (double x = startX; x <= endX; x += gridSize) {
      canvas.drawLine(
        Offset(x, visibleRect.top),
        Offset(x, visibleRect.bottom),
        paint,
      );
    }

    for (double y = startY; y <= endY; y += gridSize) {
      canvas.drawLine(
        Offset(visibleRect.left, y),
        Offset(visibleRect.right, y),
        paint,
      );
    }
  }
}

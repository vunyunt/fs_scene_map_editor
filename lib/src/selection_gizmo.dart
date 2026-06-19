import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SelectionGizmo extends PositionComponent with HasGameReference {
  final PositionComponent target;
  final bool Function() isPrimary;

  SelectionGizmo({required this.target, required this.isPrimary}) {
    // High priority to render above everything else
    priority = 1000;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (target.isRemoved) {
      removeFromParent();
      return;
    }

    // Sync with target's world transform
    position = target.absolutePosition;
    size = target.size;
    angle = target
        .angle; // Chunks are not rotated/scaled, so local is effectively global here.
    scale = target.scale;
    anchor = target.anchor;
  }

  @override
  void render(Canvas canvas) {
    final color = isPrimary()
        ? const Color(0xFFFFD54F)
        : const Color(0xFF00FFFF);

    final zoom = game.camera.viewfinder.zoom;
    final sx = scale.x.abs();
    final sy = scale.y.abs();
    final pixelRatioX = sx * zoom;
    final pixelRatioY = sy * zoom;

    final double strokeWidth = (isPrimary() ? 3.0 : 2.0) /
        (pixelRatioX > 0.0001 ? pixelRatioX : 1.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw a rectangle around the component
    canvas.drawRect(size.toRect(), paint);

    // Draw small squares at corners
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cornerSizeX = (isPrimary() ? 6.0 : 4.0) /
        (pixelRatioX > 0.0001 ? pixelRatioX : 1.0);
    final cornerSizeY = (isPrimary() ? 6.0 : 4.0) /
        (pixelRatioY > 0.0001 ? pixelRatioY : 1.0);

    canvas.drawRect(Rect.fromLTWH(0, 0, cornerSizeX, cornerSizeY), cornerPaint);
    canvas.drawRect(
      Rect.fromLTWH(size.x - cornerSizeX, 0, cornerSizeX, cornerSizeY),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.y - cornerSizeY, cornerSizeX, cornerSizeY),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.x - cornerSizeX,
        size.y - cornerSizeY,
        cornerSizeX,
        cornerSizeY,
      ),
      cornerPaint,
    );
  }
}


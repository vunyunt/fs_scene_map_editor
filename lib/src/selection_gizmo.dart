import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SelectionGizmo extends PositionComponent {
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPrimary() ? 3 : 2;

    // Draw a rectangle around the component
    canvas.drawRect(size.toRect(), paint);

    // Draw small squares at corners
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cornerSize = isPrimary() ? 6.0 : 4.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, cornerSize, cornerSize), cornerPaint);
    canvas.drawRect(
      Rect.fromLTWH(size.x - cornerSize, 0, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.y - cornerSize, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.x - cornerSize,
        size.y - cornerSize,
        cornerSize,
        cornerSize,
      ),
      cornerPaint,
    );
  }
}

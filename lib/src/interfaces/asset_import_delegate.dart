import 'package:desktop_drop/desktop_drop.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

abstract class AssetImportDelegate {
  Future<void> onDropDone(
    BuildContext context,
    DropDoneDetails details,
    Vector2 worldPos,
  );
  Widget? buildAssetButton(BuildContext context, PositionComponent target);
}

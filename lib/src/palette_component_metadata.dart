abstract interface class PaletteComponentMeta {
  /// Whether to show this component in the command palette.
  bool get showInPalette => true;

  /// Optional override for the component name shown in the command palette.
  /// If null, the standard component name will be used.
  String? get paletteLabel => null;

  /// Optional override for the component description shown in the command palette.
  /// If null, the standard component description will be used.
  String? get paletteDescription => null;

  /// Optional category to group components in the command palette.
  String get paletteCategory => '';
}

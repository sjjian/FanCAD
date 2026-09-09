import 'package:fancad_core/fancad_core.dart';

LayerDef? layerNamed(CadDocument document, String name) {
  final needle = name.toLowerCase();
  for (final layer in document.layers.values) {
    if (layer.name.toLowerCase() == needle) return layer;
  }
  return null;
}

bool sameLayerNames(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final left = {for (final name in a) name.toLowerCase()};
  final right = {for (final name in b) name.toLowerCase()};
  return left.length == right.length && left.containsAll(right);
}

Future<int?> resolveViewportIndex(CommandContext context, Layout layout) async {
  final requested = context.args.integer('index');
  if (requested != null) {
    if (requested < 0 || requested >= layout.viewports.length) return null;
    return requested;
  }
  final selected = context.selection.viewportIndices;
  if (selected.length == 1) {
    final index = selected.single;
    if (index >= 0 && index < layout.viewports.length) return index;
  }
  if (layout.viewports.length == 1) return 0;
  final point = await context.resolvePoint('point', 'Select viewport:');
  for (var i = layout.viewports.length - 1; i >= 0; i--) {
    if (layout.viewports[i].paperBounds.containsPoint(point.x, point.y)) {
      return i;
    }
  }
  return null;
}

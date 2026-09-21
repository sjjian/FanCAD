import 'package:fancad_core/fancad_core.dart';

Layout? layoutNamed(CadDocument document, String name) {
  final needle = name.toLowerCase();
  for (final layout in document.layouts) {
    if (layout.name.toLowerCase() == needle) return layout;
  }
  return null;
}

String nextLayoutName(CadDocument document) {
  final taken = {
    for (final layout in document.layouts) layout.name.toLowerCase(),
  };
  var n = 1;
  while (taken.contains('layout$n')) {
    n++;
  }
  return 'Layout$n';
}

String nextPaperBlock(CadDocument document) {
  const prefix = '*Paper_Space';
  final used = {
    ...document.blocks.keys,
    for (final layout in document.layouts) layout.blockName,
  };
  if (!used.contains(prefix)) return prefix;
  var n = 0;
  while (used.contains('$prefix$n')) {
    n++;
  }
  return '$prefix$n';
}

import 'package:flutter/foundation.dart';

/// Maps a drawing STYLE font name onto a system face.
///
/// SHX files are not loaded this round. A shape style still has to pick a
/// TTF so Chinese notes keep a CJK width instead of a Western mono fallback
/// that squeezes the title block.
class DrawingFontMap {
  const DrawingFontMap();

  static final _cjk = RegExp(
    r'[\u3000-\u303f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
  );

  static bool containsCjk(String text) => _cjk.hasMatch(text);

  String resolve({
    required String styleFont,
    required String bigFont,
    required String text,
  }) {
    final wantsCjk = bigFont.isNotEmpty || containsCjk(text);
    if (wantsCjk) return cjkFamily;
    final mapped = familyFromName(styleFont);
    if (mapped != null) return mapped;
    if (_isShx(styleFont)) return latinFallback;
    if (styleFont.isEmpty) return latinFallback;
    return styleFont;
  }

  String get cjkFamily => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => 'PingFang SC',
    TargetPlatform.windows => 'Microsoft YaHei',
    TargetPlatform.linux => 'Noto Sans CJK SC',
    _ => 'sans-serif',
  };

  String get latinFallback => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => 'Helvetica Neue',
    _ => 'Arial',
  };

  /// Arial.ttf, 宋体, times → a system family the shaper already knows.
  String? familyFromName(String raw) {
    final stem = raw
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'\.(ttf|otf|ttc|shx)$', caseSensitive: false), '')
        .trim();
    if (stem.isEmpty) return null;
    final key = stem.toLowerCase();
    return switch (key) {
      'arial' => 'Arial',
      'times' || 'times new roman' || 'timesnr' => 'Times New Roman',
      'courier' || 'courier new' => 'Courier New',
      'calibri' => 'Calibri',
      'verdana' => 'Verdana',
      'tahoma' => 'Tahoma',
      'simsun' || 'song' || '宋体' || 'nsimsun' => switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => 'Songti SC',
        TargetPlatform.windows => 'SimSun',
        _ => 'Noto Serif CJK SC',
      },
      'simhei' || 'hei' || '黑体' => switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => 'Heiti SC',
        TargetPlatform.windows => 'SimHei',
        _ => 'Noto Sans CJK SC',
      },
      'microsoft yahei' || '微软雅黑' || 'msyh' => 'Microsoft YaHei',
      'pingfang' || 'pingfang sc' => 'PingFang SC',
      _ => _isShx(stem) ? null : stem,
    };
  }

  static bool _isShx(String name) {
    final key = name.toLowerCase();
    if (key.endsWith('.shx')) return true;
    return const {
      'txt',
      'simplex',
      'italic',
      'monotxt',
      'romanc',
      'romand',
      'romans',
      'romant',
      'scripts',
      'gbcbig',
      'hztxt',
      'bigfont',
    }.contains(key);
  }
}

import 'dart:math' as math;

import '../geometry/vector.dart';
import '../model/entity.dart';
import '../model/geometry_sink.dart';

/// One laid-out run of MTEXT.
class MTextRun {
  const MTextRun({
    required this.text,
    required this.origin,
    required this.height,
    this.bold = false,
    this.italic = false,
    this.font = '',
    this.color,
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.tracking = 1,
    this.underline = false,
    this.overline = false,
    this.strike = false,
    this.hAlign,
    this.barFrom,
    this.barTo,
  });

  final String text;
  final Vec2 origin;
  final double height;
  final bool bold;
  final bool italic;
  final String font;
  final int? color;
  final double widthFactor;
  final double obliqueAngle;
  final double tracking;
  final bool underline;
  final bool overline;
  final bool strike;

  /// Paragraph `\pxq` override; null keeps the entity attachment.
  final TextHAlign? hAlign;

  /// Optional fraction bar or slash, already in model space.
  final Vec2? barFrom;
  final Vec2? barTo;
}

/// Parses AutoCAD MTEXT formatting and wraps it into lines.
///
/// The codes (`\P`, `\f…;`, `\C…;`, `{…}`) are the actual payload of almost
/// every note on a professional drawing. Stripping them to a single string
/// loses line breaks and stacking, which is why this exists as a real
/// layout step rather than as a regex.
class MTextLayout {
  const MTextLayout({this.measureWidth});

  /// Optional measured width of a run. When null, wrapping uses 0.6 em per
  /// character — close enough for a missing font, wrong for a real SHX.
  final double Function(String text, double height)? measureWidth;

  List<MTextRun> layout(MTextEntity entity) {
    final paragraphs = _parse(entity.content);
    final width = entity.rectangleWidth;
    final runs = <MTextRun>[];
    var y = 0.0;

    for (final paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        y += entity.height * 1.666;
        continue;
      }
      final lines = width <= 0
          ? [paragraph]
          : _wrap(paragraph, width, entity.height);
      var firstLine = true;
      for (final line in lines) {
        if (line.isEmpty) {
          y += entity.height * 1.666;
          firstLine = false;
          continue;
        }
        final style = line.first.style;
        final indent =
            style.leftIndent + (firstLine ? style.firstIndent : 0);
        firstLine = false;
        final placed = _placeLine(
          entity,
          line,
          Vec2(entity.position.x + indent, entity.position.y - y),
        );
        runs.addAll(placed.runs);
        y += placed.lineHeight;
      }
    }
    if (runs.isEmpty) {
      return [
        MTextRun(text: '', origin: entity.position, height: entity.height),
      ];
    }
    return runs;
  }

  List<List<_Frag>> _wrap(
    List<_Frag> paragraph,
    double width,
    double entityHeight,
  ) {
    final lines = <List<_Frag>>[];
    var line = <_Frag>[];
    var lineWidth = 0.0;

    void breakLine() {
      if (line.isNotEmpty) lines.add(line);
      line = [];
      lineWidth = 0.0;
    }

    for (final frag in paragraph) {
      if (frag.stack != null) {
        final w = _stackWidth(frag, entityHeight);
        if (line.isNotEmpty && lineWidth + w > width) breakLine();
        line.add(frag);
        lineWidth += w;
        continue;
      }
      final words = frag.text.split(RegExp(r'\s+'));
      var leadingSpace = frag.text.startsWith(' ');
      for (final word in words) {
        if (word.isEmpty) continue;
        final piece = leadingSpace ? ' $word' : word;
        leadingSpace = true;
        final w = _textWidth(piece, _heightOf(frag.style, entityHeight));
        if (line.isNotEmpty && lineWidth + w > width) {
          breakLine();
          line.add(frag.withText(word));
          lineWidth = _textWidth(word, _heightOf(frag.style, entityHeight));
        } else {
          if (line.isNotEmpty && line.last.style == frag.style) {
            line[line.length - 1] = line.last.withText(
              '${line.last.text}$piece',
            );
          } else {
            line.add(frag.withText(piece));
          }
          lineWidth += w;
        }
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines.isEmpty ? [paragraph] : lines;
  }

  ({List<MTextRun> runs, double lineHeight}) _placeLine(
    MTextEntity entity,
    List<_Frag> line,
    Vec2 origin,
  ) {
    final heights = <double>[];
    for (final frag in line) {
      heights.add(
        frag.stack == null
            ? _heightOf(frag.style, entity.height)
            : _heightOf(frag.style, entity.height) * 2.2,
      );
    }
    final lineH = heights.reduce(math.max);
    final runs = <MTextRun>[];
    var x = origin.x;
    for (var i = 0; i < line.length; i++) {
      final frag = line[i];
      final h = _heightOf(frag.style, entity.height);
      final boxH = heights[i];
      final top = switch (frag.style.align) {
        2 => origin.y,
        1 => origin.y - (lineH - boxH) / 2,
        _ => origin.y - (lineH - boxH),
      };
      if (frag.stack != null) {
        final stack = frag.stack!;
        final partH = h * 0.7;
        final upperW = _textWidth(stack.upper, partH);
        final lowerW = _textWidth(stack.lower, partH);
        final stackW = math.max(upperW, lowerW);
        final midY = top - partH * 1.05;
        runs.add(
          _run(
            frag.style,
            stack.upper,
            Vec2(x + (stackW - upperW) / 2, top),
            partH,
          ),
        );
        runs.add(
          _run(
            frag.style,
            stack.lower,
            Vec2(x + (stackW - lowerW) / 2, top - partH * 1.15),
            partH,
            barFrom: stack.kind == _StackKind.none
                ? null
                : Vec2(x, midY),
            barTo: stack.kind == _StackKind.none
                ? null
                : stack.kind == _StackKind.slash
                ? Vec2(x + stackW, midY - partH * 0.2)
                : Vec2(x + stackW, midY),
          ),
        );
        x += stackW;
        continue;
      }
      if (frag.text.isEmpty) continue;
      runs.add(_run(frag.style, frag.text, Vec2(x, top), h));
      x += _textWidth(frag.text, h) * frag.style.widthFactor;
    }
    // AutoCAD's default MTEXT line space is 5/3 of the cap height. 1.2 was
    // shorter than the TTF line box, so `\P` rows sat on top of each other.
    return (runs: runs, lineHeight: math.max(lineH, entity.height) * (5 / 3));
  }

  MTextRun _run(
    _Style style,
    String text,
    Vec2 origin,
    double height, {
    Vec2? barFrom,
    Vec2? barTo,
  }) => MTextRun(
    text: text,
    origin: origin,
    height: height,
    bold: style.bold,
    italic: style.italic,
    font: style.font,
    color: style.color,
    widthFactor: style.widthFactor,
    obliqueAngle: style.obliqueAngle,
    tracking: style.tracking,
    underline: style.underline,
    overline: style.overline,
    strike: style.strike,
    hAlign: style.hAlign,
    barFrom: barFrom,
    barTo: barTo,
  );

  double _heightOf(_Style style, double entityHeight) {
    if (style.heightScale != null) return entityHeight * style.heightScale!;
    return style.height ?? entityHeight;
  }

  double _textWidth(String text, double height) {
    if (text.isEmpty || height <= 0) return 0;
    return measureWidth != null
        ? measureWidth!(text, height)
        : text.length * height * 0.6;
  }

  double _stackWidth(_Frag frag, double entityHeight) {
    final h = _heightOf(frag.style, entityHeight) * 0.7;
    final stack = frag.stack!;
    return math.max(_textWidth(stack.upper, h), _textWidth(stack.lower, h));
  }

  List<List<_Frag>> _parse(String raw) {
    final paragraphs = <List<_Frag>>[<_Frag>[]];
    var style = _Style();
    final saved = <_Style>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      paragraphs.last.add(_Frag(text: buffer.toString(), style: style.copy()));
      buffer.clear();
    }

    var i = 0;
    while (i < raw.length) {
      final char = raw[i];
      if (char == '\\' && i + 1 < raw.length) {
        final code = raw[i + 1];
        switch (code) {
          case 'P':
            flush();
            paragraphs.add([]);
            i += 2;
            continue;
          case '~':
            buffer.write(' ');
            i += 2;
            continue;
          case '\\':
          case '{':
          case '}':
            buffer.write(code);
            i += 2;
            continue;
          case 'L':
            flush();
            style = style.copy(underline: true);
            i += 2;
            continue;
          case 'l':
            flush();
            style = style.copy(underline: false);
            i += 2;
            continue;
          case 'O':
            flush();
            style = style.copy(overline: true);
            i += 2;
            continue;
          case 'o':
            flush();
            style = style.copy(overline: false);
            i += 2;
            continue;
          case 'K':
            flush();
            style = style.copy(strike: true);
            i += 2;
            continue;
          case 'k':
            flush();
            style = style.copy(strike: false);
            i += 2;
            continue;
          case 'U':
            if (i + 6 < raw.length && raw[i + 2] == '+') {
              final value = int.tryParse(
                raw.substring(i + 3, i + 7),
                radix: 16,
              );
              if (value != null) {
                buffer.writeCharCode(value);
                i += 7;
                continue;
              }
            }
            break;
          case 'M':
            if (i + 7 < raw.length && raw[i + 2] == '+') {
              final value = int.tryParse(
                raw.substring(i + 4, i + 8),
                radix: 16,
              );
              if (value != null) {
                buffer.writeCharCode(value);
                i += 8;
                continue;
              }
            }
            break;
        }
        flush();
        final end = raw.indexOf(';', i);
        if (end == -1) {
          i += 2;
          continue;
        }
        final directive = raw.substring(i + 1, end);
        if (directive.isNotEmpty &&
            (directive[0] == 'S' || directive[0] == 's')) {
          final stack = _Stack.parse(directive.substring(1));
          if (stack != null) {
            paragraphs.last.add(_Frag(text: '', style: style.copy(), stack: stack));
          }
        } else {
          style = style.applying(directive);
          if (directive.isNotEmpty && directive[0] == 'p') {
            paragraphs.last = [
              for (final frag in paragraphs.last)
                _Frag(
                  text: frag.text,
                  style: frag.style.copy(
                    firstIndent: style.firstIndent,
                    leftIndent: style.leftIndent,
                    rightIndent: style.rightIndent,
                    hAlign: style.hAlign,
                  ),
                  stack: frag.stack,
                ),
            ];
          }
        }
        i = end + 1;
        continue;
      }
      if (char == '{') {
        flush();
        saved.add(style.copy());
        i++;
        continue;
      }
      if (char == '}') {
        flush();
        if (saved.isNotEmpty) style = saved.removeLast();
        i++;
        continue;
      }
      buffer.write(char);
      i++;
    }
    flush();
    if (paragraphs.length == 1 && paragraphs.first.isEmpty) {
      paragraphs.first.add(_Frag(text: '', style: _Style()));
    }
    return paragraphs;
  }
}

/// Readable MTEXT content: codes removed, `\P` is a newline, `\U+` is a glyph.
String decodeMTextPlain(String raw) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    final char = raw[i];
    if (char == '\\' && i + 1 < raw.length) {
      final code = raw[i + 1];
      switch (code) {
        case 'P':
          buffer.write('\n');
          i += 2;
          continue;
        case '~':
          buffer.write(' ');
          i += 2;
          continue;
        case '\\':
        case '{':
        case '}':
          buffer.write(code);
          i += 2;
          continue;
        case 'L':
        case 'l':
        case 'O':
        case 'o':
        case 'K':
        case 'k':
          i += 2;
          continue;
        case 'U':
          if (i + 6 < raw.length && raw[i + 2] == '+') {
            final value = int.tryParse(raw.substring(i + 3, i + 7), radix: 16);
            if (value != null) {
              buffer.writeCharCode(value);
              i += 7;
              continue;
            }
          }
          break;
        case 'M':
          if (i + 7 < raw.length && raw[i + 2] == '+') {
            final value = int.tryParse(raw.substring(i + 4, i + 8), radix: 16);
            if (value != null) {
              buffer.writeCharCode(value);
              i += 8;
              continue;
            }
          }
          break;
      }
      final end = raw.indexOf(';', i);
      if (end == -1) {
        i += 2;
        continue;
      }
      final directive = raw.substring(i + 1, end);
      if (directive.isNotEmpty &&
          (directive[0] == 'S' || directive[0] == 's')) {
        final stack = _Stack.parse(directive.substring(1));
        if (stack != null) {
          buffer.write(stack.upper);
          if (stack.kind != _StackKind.none) buffer.write('/');
          buffer.write(stack.lower);
        }
      }
      i = end + 1;
      continue;
    }
    if (char == '{' || char == '}') {
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }
  return buffer.toString();
}

class _Frag {
  const _Frag({required this.text, required this.style, this.stack});

  final String text;
  final _Style style;
  final _Stack? stack;

  _Frag withText(String value) =>
      _Frag(text: value, style: style, stack: stack);
}

enum _StackKind { bar, slash, none }

class _Stack {
  const _Stack(this.upper, this.lower, this.kind);

  final String upper;
  final String lower;
  final _StackKind kind;

  static _Stack? parse(String rest) {
    final hash = rest.indexOf('#');
    final slash = rest.indexOf('/');
    final caret = rest.indexOf('^');
    var at = -1;
    var kind = _StackKind.none;
    if (hash >= 0 && (slash < 0 || hash < slash) && (caret < 0 || hash < caret)) {
      at = hash;
      kind = _StackKind.bar;
    } else if (slash >= 0 && (caret < 0 || slash < caret)) {
      at = slash;
      kind = _StackKind.slash;
    } else if (caret >= 0) {
      at = caret;
    }
    if (at < 0) return null;
    return _Stack(rest.substring(0, at), rest.substring(at + 1), kind);
  }
}

class _Style {
  _Style({
    this.height,
    this.heightScale,
    this.bold = false,
    this.italic = false,
    this.font = '',
    this.color,
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.tracking = 1,
    this.underline = false,
    this.overline = false,
    this.strike = false,
    this.align = 0,
    this.firstIndent = 0,
    this.leftIndent = 0,
    this.rightIndent = 0,
    this.hAlign,
  });

  final double? height;
  final double? heightScale;
  final bool bold;
  final bool italic;
  final String font;
  final int? color;
  final double widthFactor;
  final double obliqueAngle;
  final double tracking;
  final bool underline;
  final bool overline;
  final bool strike;

  /// `\A`: 0 bottom, 1 centre, 2 top of the line.
  final int align;
  final double firstIndent;
  final double leftIndent;
  final double rightIndent;
  final TextHAlign? hAlign;

  _Style copy({
    double? height,
    double? heightScale,
    bool? bold,
    bool? italic,
    String? font,
    int? color,
    double? widthFactor,
    double? obliqueAngle,
    double? tracking,
    bool? underline,
    bool? overline,
    bool? strike,
    int? align,
    double? firstIndent,
    double? leftIndent,
    double? rightIndent,
    TextHAlign? hAlign,
    bool clearHeight = false,
    bool clearHeightScale = false,
    bool clearColor = false,
    bool clearHAlign = false,
  }) => _Style(
    height: clearHeight ? null : (height ?? this.height),
    heightScale: clearHeightScale ? null : (heightScale ?? this.heightScale),
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    font: font ?? this.font,
    color: clearColor ? null : (color ?? this.color),
    widthFactor: widthFactor ?? this.widthFactor,
    obliqueAngle: obliqueAngle ?? this.obliqueAngle,
    tracking: tracking ?? this.tracking,
    underline: underline ?? this.underline,
    overline: overline ?? this.overline,
    strike: strike ?? this.strike,
    align: align ?? this.align,
    firstIndent: firstIndent ?? this.firstIndent,
    leftIndent: leftIndent ?? this.leftIndent,
    rightIndent: rightIndent ?? this.rightIndent,
    hAlign: clearHAlign ? null : (hAlign ?? this.hAlign),
  );

  _Style applying(String directive) {
    if (directive.isEmpty) return this;
    final code = directive[0];
    final rest = directive.substring(1);
    switch (code) {
      case 'f':
      case 'F':
        final name = rest.split('|').first;
        return copy(
          bold: rest.contains('|b1') || rest.contains('|B1'),
          italic: rest.contains('|i1') || rest.contains('|I1'),
          font: name,
        );
      case 'H':
      case 'h':
        final relative = rest.toLowerCase().endsWith('x');
        final value = double.tryParse(rest.replaceAll(RegExp('[xX]'), ''));
        if (relative) {
          return copy(heightScale: value, clearHeight: true);
        }
        return copy(height: value, clearHeightScale: true);
      case 'C':
      case 'c':
        return copy(color: int.tryParse(rest));
      case 'W':
      case 'w':
        return copy(widthFactor: double.tryParse(rest) ?? widthFactor);
      case 'Q':
      case 'q':
        final degrees = double.tryParse(rest);
        return copy(
          obliqueAngle: degrees == null
              ? obliqueAngle
              : degrees * math.pi / 180,
        );
      case 'T':
      case 't':
        return copy(tracking: double.tryParse(rest) ?? tracking);
      case 'A':
      case 'a':
        return copy(align: int.tryParse(rest) ?? align);
      case 'p':
        return _applyParagraph(rest);
      default:
        return this;
    }
  }

  _Style _applyParagraph(String rest) {
    var i = 0;
    var first = firstIndent;
    var left = leftIndent;
    var right = rightIndent;
    var alignH = hAlign;
    while (i < rest.length) {
      final c = rest[i].toLowerCase();
      if (c == 'x') {
        i++;
        continue;
      }
      if (c == 'q' && i + 1 < rest.length) {
        alignH = switch (rest[i + 1].toLowerCase()) {
          'c' => TextHAlign.center,
          'r' => TextHAlign.right,
          _ => TextHAlign.left,
        };
        i += 2;
        continue;
      }
      if (c == 't') break;
      if (c == 'i' || c == 'l' || c == 'r') {
        var end = i + 1;
        if (end < rest.length && (rest[end] == '-' || rest[end] == '+')) {
          end++;
        }
        while (end < rest.length &&
            ((rest.codeUnitAt(end) >= 48 && rest.codeUnitAt(end) <= 57) ||
                rest[end] == '.')) {
          end++;
        }
        final value = double.tryParse(rest.substring(i + 1, end));
        if (value != null) {
          if (c == 'i') first = value;
          if (c == 'l') left = value;
          if (c == 'r') right = value;
        }
        i = end;
        continue;
      }
      i++;
    }
    return copy(firstIndent: first, leftIndent: left, rightIndent: right, hAlign: alignH);
  }

  @override
  bool operator ==(Object other) =>
      other is _Style &&
      other.height == height &&
      other.heightScale == heightScale &&
      other.bold == bold &&
      other.italic == italic &&
      other.font == font &&
      other.color == color &&
      other.widthFactor == widthFactor &&
      other.obliqueAngle == obliqueAngle &&
      other.tracking == tracking &&
      other.underline == underline &&
      other.overline == overline &&
      other.strike == strike &&
      other.align == align;

  @override
  int get hashCode => Object.hash(
    height,
    heightScale,
    bold,
    italic,
    font,
    color,
    widthFactor,
    underline,
    overline,
    strike,
    align,
  );
}

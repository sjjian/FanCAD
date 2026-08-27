import '../geometry/vector.dart';
import '../model/entity.dart';

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
  });

  final String text;
  final Vec2 origin;
  final double height;
  final bool bold;
  final bool italic;
  final String font;
  final int? color;
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
    final lineHeight = entity.height * 1.666;
    final runs = <MTextRun>[];
    var y = 0.0;

    for (final paragraph in paragraphs) {
      if (width <= 0) {
        runs.add(
          _runAt(entity, paragraph, Vec2(entity.position.x, entity.position.y - y)),
        );
        y += lineHeight;
        continue;
      }
      final words = paragraph.text.split(RegExp(r'\s+'));
      var line = StringBuffer();
      // A conservative width estimate: 0.6 em per character, which is what
      // SHX simplex measures at and close enough for wrapping decisions
      // when no font is supplied. A real [measureWidth] wins.
      final em = entity.height * 0.6;
      double widthOf(String text) => measureWidth != null
          ? measureWidth!(text, entity.height)
          : text.length * em;
      for (final word in words) {
        if (word.isEmpty) continue;
        final candidate = line.isEmpty ? word : '$line $word';
        if (widthOf(candidate) > width && line.isNotEmpty) {
          runs.add(
            _runAt(
              entity,
              paragraph.withText(line.toString()),
              Vec2(entity.position.x, entity.position.y - y),
            ),
          );
          y += lineHeight;
          line = StringBuffer(word);
        } else {
          line = StringBuffer(candidate);
        }
      }
      if (line.isNotEmpty) {
        runs.add(
          _runAt(
            entity,
            paragraph.withText(line.toString()),
            Vec2(entity.position.x, entity.position.y - y),
          ),
        );
        y += lineHeight;
      }
    }
    return runs;
  }

  MTextRun _runAt(MTextEntity entity, _Span span, Vec2 origin) => MTextRun(
    text: span.text,
    origin: origin,
    height: span.height ?? entity.height,
    bold: span.bold,
    italic: span.italic,
    font: span.font,
    color: span.color,
  );

  List<_Span> _parse(String raw) {
    final spans = <_Span>[];
    var current = _Span();
    final buffer = StringBuffer();

    void flush({bool newParagraph = false}) {
      if (buffer.isNotEmpty) {
        spans.add(current.withText(buffer.toString()));
        buffer.clear();
      } else if (newParagraph && spans.isNotEmpty) {
        spans.add(current.withText(''));
      }
    }

    var i = 0;
    while (i < raw.length) {
      final char = raw[i];
      if (char == '\\' && i + 1 < raw.length) {
        final code = raw[i + 1];
        switch (code) {
          case 'P':
          case 'p':
            flush(newParagraph: true);
            current = current.copy();
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
          default:
            flush();
            final end = raw.indexOf(';', i);
            if (end == -1) {
              i += 2;
              continue;
            }
            final directive = raw.substring(i + 1, end);
            current = current.applying(directive);
            i = end + 1;
            continue;
        }
      }
      if (char == '{' || char == '}') {
        i++;
        continue;
      }
      buffer.write(char);
      i++;
    }
    flush();
    if (spans.isEmpty) spans.add(_Span(text: stripMTextFormatting(raw)));
    return spans;
  }
}

class _Span {
  _Span({
    this.text = '',
    this.height,
    this.bold = false,
    this.italic = false,
    this.font = '',
    this.color,
  });

  final String text;
  final double? height;
  final bool bold;
  final bool italic;
  final String font;
  final int? color;

  _Span withText(String value) => _Span(
    text: value,
    height: height,
    bold: bold,
    italic: italic,
    font: font,
    color: color,
  );

  _Span copy() => withText(text);

  _Span applying(String directive) {
    if (directive.isEmpty) return this;
    final code = directive[0];
    final rest = directive.substring(1);
    switch (code) {
      case 'f':
      case 'F':
        final name = rest.split('|').first;
        final bold = rest.contains('|b1') || rest.contains('|B1');
        final italic = rest.contains('|i1') || rest.contains('|I1');
        return _Span(
          height: height,
          bold: bold,
          italic: italic,
          font: name,
          color: color,
        );
      case 'H':
      case 'h':
        final value = double.tryParse(rest.replaceAll('x', ''));
        return _Span(
          height: value,
          bold: bold,
          italic: italic,
          font: font,
          color: color,
        );
      case 'C':
      case 'c':
        return _Span(
          height: height,
          bold: bold,
          italic: italic,
          font: font,
          color: int.tryParse(rest),
        );
      default:
        return this;
    }
  }
}

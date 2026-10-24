import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';

import '../chip.dart';
import '../empty.dart';
import '../field.dart';
import '../menu.dart';
import '../tokens.dart';
import 'props.dart';

/// Compact accent button. Same metrics as the shell's filled button.
class FanCadButton extends StatefulWidget {
  const FanCadButton({super.key, required this.props, required this.onPressed});

  final FanCadButtonProps props;
  final VoidCallback? onPressed;

  @override
  State<FanCadButton> createState() => _FanCadButtonState();
}

class _FanCadButtonState extends State<FanCadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = widget.onPressed != null;
    final fill = !enabled
        ? tokens.disabled
        : _hovered
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.12), tokens.accent)
        : tokens.accent;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space4,
            ),
            // Hug the label. A Container with an alignment expands to the
            // parent's max width, so a row of dialog buttons becomes a stack
            // of full-width bars.
            child: SizedBox(
              height: 28,
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  widget.props.label,
                  style: tokens.bodyStyle.copyWith(color: tokens.accentText),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined field shared by `textField` and `numberField`.
class FanCadFormField extends StatelessWidget {
  const FanCadFormField({
    super.key,
    required this.props,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final FanCadFormFieldProps props;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SettingsTextField(
      controller: controller,
      focusNode: focusNode,
      hintText: props.placeholder,
      keyboardType: props.number ? TextInputType.number : null,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// A checkbox and its label on one dense row.
class FanCadCheckbox extends StatelessWidget {
  const FanCadCheckbox({
    super.key,
    required this.props,
    required this.onChanged,
  });

  final FanCadCheckboxProps props;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!props.value),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: props.value,
              onChanged: (value) => onChanged(value == true),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: FanCadTokens.space2),
          Expanded(
            child: Text(
              props.label,
              style: tokens.bodyStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu field. [FanCadDropdownProps.options] is the closed list.
class FanCadDropdown extends StatelessWidget {
  const FanCadDropdown({
    super.key,
    required this.props,
    required this.onChanged,
  });

  final FanCadDropdownProps props;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final current = props.options.contains(props.value) ? props.value : null;
    final faded = current == null;
    final label = current ?? props.placeholder ?? '';
    return FanCadMenuButton<String>(
      placement: FanCadMenuPlacement.down,
      matchTriggerWidth: true,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in props.options)
          fanCadMenuItem(
            context,
            value: option,
            label: option,
            checked: option == current,
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tokens.bodyStyle.copyWith(
                  color: faded ? tokens.textFaint : tokens.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: FanCadTokens.iconSmall,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin track. The value is the plugin's number, not a Material thumb.
class FanCadSlider extends StatelessWidget {
  const FanCadSlider({super.key, required this.props, required this.onChanged});

  final FanCadSliderProps props;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final span = props.max - props.min;
    final t = span <= 0 ? 0.0 : (props.value - props.min) / span;
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          void apply(double dx) {
            if (width <= 0 || span <= 0) return;
            final next = props.min + (dx / width).clamp(0.0, 1.0) * span;
            onChanged(next);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => apply(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                apply(details.localPosition.dx),
            child: CustomPaint(
              painter: _SliderPainter(t: t.clamp(0.0, 1.0), tokens: tokens),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({required this.t, required this.tokens});

  final double t;
  final FanCadTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()
      ..color = tokens.border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final filled = Paint()
      ..color = tokens.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), track);
    final x = size.width * t;
    canvas.drawLine(Offset(0, y), Offset(x, y), filled);
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = tokens.accent);
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.tokens != tokens;
}

class FanCadNodeText extends StatelessWidget {
  const FanCadNodeText({super.key, required this.props});

  final FanCadTextProps props;

  @override
  Widget build(BuildContext context) {
    return Text(props.text, style: context.tokens.bodyStyle);
  }
}

class FanCadNodeIcon extends StatelessWidget {
  const FanCadNodeIcon({super.key, required this.props});

  final FanCadIconProps props;

  @override
  Widget build(BuildContext context) {
    return Icon(fanCadNamedIcon(props.name), color: context.tokens.text);
  }
}

class FanCadNodeImage extends StatelessWidget {
  const FanCadNodeImage({super.key, required this.file});

  final File? file;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    if (file == null) return const SizedBox.shrink();
    return Image.file(file, height: 48, fit: BoxFit.contain);
  }
}

class FanCadEntityChip extends StatelessWidget {
  const FanCadEntityChip({
    super.key,
    required this.props,
    required this.onPressed,
  });

  final FanCadEntityChipProps props;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PromptKeywordChip(label: props.label, onPressed: onPressed),
    );
  }
}

/// ACI swatch used by text editing and by a plugin `colorField`.
class FanCadColorField extends StatelessWidget {
  const FanCadColorField({
    super.key,
    required this.props,
    required this.onChanged,
  });

  static const _swatches = [1, 2, 3, 4, 5, 6, 7];

  final FanCadColorFieldProps props;
  final ValueChanged<CadColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = tokens.isDark ? AciPalette.dark : AciPalette.light;
    final color = props.color;
    final swatch = color.isInherited
        ? tokens.textFaint
        : palette.colorOf(color);
    return FanCadMenuButton<CadColor>(
      placement: FanCadMenuPlacement.down,
      tooltip: props.tooltip,
      onSelected: onChanged,
      itemBuilder: (context) => [
        fanCadMenuItem(
          context,
          value: const CadColor.byLayer(),
          label: props.byLayerLabel,
          checked: color.kind == ColorKind.byLayer,
        ),
        for (final index in _swatches)
          fanCadMenuItem(
            context,
            value: CadColor.indexed(index),
            label: '$index',
            checked: color.kind == ColorKind.indexed && color.value == index,
            leading: _swatchBox(
              palette.colorOf(CadColor.indexed(index)),
              tokens.border,
            ),
          ),
      ],
      child: Container(
        width: props.width,
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        ),
        child: Row(
          children: [
            _swatchBox(swatch, tokens.border),
            const SizedBox(width: FanCadTokens.space1),
            Expanded(
              child: Text(
                props.label,
                style: tokens.monoStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: FanCadTokens.iconSmall,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatchBox(Color color, Color border) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Static inset. Coordinates are drawing units, y up, and nothing here is an
/// entity.
class FanCadPreview extends StatelessWidget {
  const FanCadPreview({super.key, required this.props});

  final FanCadPreviewProps props;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final caption = props.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
            child: Text(caption, style: tokens.labelStyle),
          ),
        SizedBox(
          height: props.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.canvas,
              border: Border.all(color: tokens.border),
            ),
            child: CustomPaint(
              painter: _PreviewPainter(
                shapes: props.shapes,
                color: tokens.accent,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

/// A plugin-owned [CadCanvas]. Pan, zoom and the grid are the real viewport.
///
/// The document is not a drawing tab. The same canvas can stay invisible
/// until a view tree places this node.
class FanCadViewer extends StatefulWidget {
  const FanCadViewer({
    super.key,
    required this.props,
    required this.binding,
    required this.closedLabel,
  });

  final FanCadViewerProps props;
  final FanCadViewerBinding? binding;
  final String closedLabel;

  @override
  State<FanCadViewer> createState() => _FanCadViewerState();
}

/// A document a plugin owns, handed to [FanCadViewer] by the host.
///
/// [retain] and [release] keep the host from disposing the camera while this
/// widget is still listening.
class FanCadViewerBinding {
  const FanCadViewerBinding({
    required this.document,
    required this.viewport,
    this.changes,
    this.retain,
    this.release,
  });

  final CadDocument document;
  final ViewportController viewport;
  final Stream<Object?>? changes;
  final VoidCallback? retain;
  final VoidCallback? release;
}

class _FanCadViewerState extends State<FanCadViewer> {
  CadDocument? _document;
  ViewportController? _viewport;
  StreamSubscription<Object?>? _changes;
  VoidCallback? _release;
  var _retained = false;

  @override
  void initState() {
    super.initState();
    _hold(widget.binding);
  }

  @override
  void didUpdateWidget(FanCadViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.binding;
    if (identical(next?.document, _document) &&
        identical(next?.viewport, _viewport)) {
      return;
    }
    _drop();
    _hold(next);
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  void _hold(FanCadViewerBinding? binding) {
    if (binding == null) return;
    _document = binding.document;
    _viewport = binding.viewport;
    _release = binding.release;
    binding.retain?.call();
    _retained = true;
    _changes = binding.changes?.listen((_) {
      if (mounted) setState(() {});
    });
    binding.viewport.addListener(_onCamera);
  }

  void _onCamera() {
    if (mounted) setState(() {});
  }

  void _drop() {
    _changes?.cancel();
    _changes = null;
    _viewport?.removeListener(_onCamera);
    if (_retained) {
      _release?.call();
      _retained = false;
    }
    _release = null;
    _document = null;
    _viewport = null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final caption = widget.props.caption;
    final document = _document;
    final viewport = _viewport;
    final hasCaption = caption != null && caption.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A short card must be able to shrink this canvas. A fixed height
        // taller than the slot overflows the column and covers the controls.
        // The column stays as tall as the picture, so a max height on the
        // slot does not turn into empty space under a short canvas.
        final captionBlock = hasCaption
            ? FanCadTokens.space1 +
                  tokens.labelStyle.fontSize! *
                      (tokens.labelStyle.height ?? 1) +
                  2
            : 0.0;
        var canvasHeight = widget.props.height;
        if (constraints.maxHeight.isFinite) {
          final room = constraints.maxHeight - captionBlock;
          canvasHeight = math.min(canvasHeight, math.max(0, room));
        }
        final canvas = DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: tokens.border)),
          child: document == null || viewport == null
              ? FanCadEmpty(message: widget.closedLabel)
              : CadCanvas(
                  document: document,
                  controller: viewport,
                  background: tokens.canvas,
                  showGrid: true,
                ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
                child: Text(caption, style: tokens.labelStyle),
              ),
            SizedBox(height: canvasHeight, child: canvas),
          ],
        );
      },
    );
  }
}

/// Fits plugin preview shapes into the inset. Coordinates are drawing units,
/// y up, the same as `canvas.preview`, but nothing here is an entity.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter({required this.shapes, required this.color});

  final Object? shapes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final figure = _PreviewFigure.parse(shapes);
    if (figure.points.isEmpty) return;
    var minX = figure.points.first.dx;
    var minY = figure.points.first.dy;
    var maxX = minX;
    var maxY = minY;
    for (final point in figure.points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy > maxY) maxY = point.dy;
    }
    const pad = 16.0;
    final width = math.max(maxX - minX, 1);
    final height = math.max(maxY - minY, 1);
    final scale = math.min(
      (size.width - pad * 2) / width,
      (size.height - pad * 2) / height,
    );
    Offset map(Offset point) => Offset(
      pad + (point.dx - minX) * scale,
      size.height - pad - (point.dy - minY) * scale,
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final segment in figure.lines) {
      if (segment.length < 2) continue;
      final path = Path()..moveTo(map(segment.first).dx, map(segment.first).dy);
      for (final point in segment.skip(1)) {
        final mapped = map(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      canvas.drawPath(path, stroke);
    }
    for (final point in figure.dots) {
      canvas.drawCircle(map(point), 2.5, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) => true;
}

class _PreviewFigure {
  const _PreviewFigure(this.lines, this.dots, this.points);

  final List<List<Offset>> lines;
  final List<Offset> dots;
  final List<Offset> points;

  static _PreviewFigure parse(Object? raw) {
    final lines = <List<Offset>>[];
    final dots = <Offset>[];
    final points = <Offset>[];
    if (raw is! List) return _PreviewFigure(lines, dots, points);
    for (final value in raw) {
      if (value is! Map) continue;
      final type = value['type'];
      if (type == 'line') {
        final start = _previewPoint(value['start']);
        final end = _previewPoint(value['end']);
        if (start == null || end == null) continue;
        lines.add([start, end]);
        points.addAll([start, end]);
      } else if (type == 'polyline') {
        final segment = <Offset>[];
        final rawPoints = value['points'];
        if (rawPoints is List) {
          for (final point in rawPoints) {
            final parsed = _previewPoint(point);
            if (parsed != null) segment.add(parsed);
          }
        }
        if (segment.length < 2) continue;
        lines.add(segment);
        points.addAll(segment);
      } else if (type == 'rect') {
        final bounds = value['bounds'];
        if (bounds is! List || bounds.length < 4) continue;
        final minX = bounds[0];
        final minY = bounds[1];
        final maxX = bounds[2];
        final maxY = bounds[3];
        if (minX is! num || minY is! num || maxX is! num || maxY is! num) {
          continue;
        }
        final segment = [
          Offset(minX.toDouble(), minY.toDouble()),
          Offset(maxX.toDouble(), minY.toDouble()),
          Offset(maxX.toDouble(), maxY.toDouble()),
          Offset(minX.toDouble(), maxY.toDouble()),
          Offset(minX.toDouble(), minY.toDouble()),
        ];
        lines.add(segment);
        points.addAll(segment);
      } else if (type == 'point') {
        final at = _previewPoint(value['at']);
        if (at == null) continue;
        dots.add(at);
        points.add(at);
      }
    }
    return _PreviewFigure(lines, dots, points);
  }
}

Offset? _previewPoint(Object? raw) {
  if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
    return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
  }
  if (raw is Map) {
    final x = raw['x'];
    final y = raw['y'];
    if (x is num && y is num) return Offset(x.toDouble(), y.toDouble());
  }
  return null;
}

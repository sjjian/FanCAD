import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'js_highlight.dart';
import 'line_gutter.dart';

/// Opens [name] in the extension editor over the canvas.
Future<void> showExtensionEditor(
  BuildContext context, {
  required String name,
  required Workspace workspace,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => ExtensionEditor(name: name, workspace: workspace),
  );
}

/// One saved extension's source, with highlighting, line numbers and Save.
class ExtensionEditor extends ConsumerStatefulWidget {
  const ExtensionEditor({
    super.key,
    required this.name,
    required this.workspace,
  });

  final String name;
  final Workspace workspace;

  @override
  ConsumerState<ExtensionEditor> createState() => _ExtensionEditorState();
}

class _ExtensionEditorState extends ConsumerState<ExtensionEditor> {
  final _JsSourceController _body = _JsSourceController();
  final ScrollController _scroll = ScrollController();
  String? _error;
  bool _dirty = false;
  bool _opened = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.workspace.runHeadless(
      'extensions.read',
      args: {'name': widget.name},
    );
    if (!mounted) return;
    if (!result.isOk) {
      final error = context.l10n.extension_read_failed(
        widget.name,
        result.message,
      );
      setState(() => _error = error);
      return;
    }
    final content = result.data?['content'];
    _applying = true;
    _body.text = content is String ? content : '';
    _applying = false;
    setState(() {
      _opened = true;
      _dirty = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_opened || !_dirty) return;
    final saved = _body.text;
    final l10n = context.l10n;
    final result = await widget.workspace.runHeadless(
      'extensions.write',
      args: {'name': widget.name, 'content': saved},
    );
    if (!mounted) return;
    setState(() {
      if (!result.isOk) {
        _error = l10n.extension_save_failed(widget.name, result.message);
        return;
      }
      _error = null;
      // Typing while the write was in flight is still unsaved.
      if (_body.text == saved) _dirty = false;
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    if (!mounted) return false;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        final tokens = context.tokens;
        return AlertDialog(
          backgroundColor: tokens.surfaceOverlay,
          title: Text(context.l10n.unsaved_extension_changes(widget.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(context.l10n.dont_save),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    if (choice == 'save') {
      await _save();
      return !_dirty;
    }
    return choice == 'discard';
  }

  Future<void> _requestClose() async {
    if (!await _confirmLeave()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _ExtensionWindow(
      name: 'extension-${widget.name}',
      title: '${context.l10n.edit_extension} · ${widget.name}',
      onClose: () => unawaited(_requestClose()),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: tokens.surfaceRaised,
              child: SizedBox(
                height: FanCadTokens.filterBarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FanCadTokens.space1,
                  ),
                  child: Row(
                    children: [
                      FanCadIconButton(
                        key: const Key('extension-editor-save'),
                        icon: Icons.save_outlined,
                        tooltip: context.l10n.save,
                        size: 24,
                        enabled: _opened && _dirty,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const FanCadHairline(strong: false),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                  vertical: FanCadTokens.space1,
                ),
                child: Text(
                  _error!,
                  style: tokens.labelStyle.copyWith(color: tokens.danger),
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LineGutter(
                    key: const Key('extension-editor-lines'),
                    controller: _body,
                    scroll: _scroll,
                    style: _editorStyle(tokens),
                    strut: _editorStrut,
                    lineHeight: _editorLineHeight,
                    // InputDecorator shifts the field by half the
                    // visual-density adjustment, so the numbers use that same
                    // inset or they sit a step below the text.
                    top:
                        _editorPadding.top +
                        Theme.of(context).visualDensity.baseSizeAdjustment.dy /
                            2,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _body,
                      scrollController: _scroll,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: _editorStyle(tokens),
                      strutStyle: _editorStrut,
                      cursorColor: tokens.text,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: _editorPadding,
                      ),
                      onChanged: (_) {
                        if (_applying || _dirty) return;
                        setState(() => _dirty = true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionWindow extends StatelessWidget {
  const _ExtensionWindow({
    required this.name,
    required this.title,
    required this.child,
    required this.onClose,
  });

  final String name;
  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        if (!bounds.isFinite || bounds.isEmpty) return const SizedBox.shrink();
        final size = _editorWindowSize(bounds);
        return SizedBox.expand(
          child: Stack(
            children: [
              FanCadCanvasWindow(
                name: name,
                title: title,
                origin: Offset(
                  (bounds.width - size.width) / 2,
                  (bounds.height - size.height) / 2,
                ),
                bounds: bounds,
                initialSize: size,
                minSize: const Size(420, 280),
                closeTooltip: context.l10n.close,
                onClose: onClose,
                onBarrierTap: onClose,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Most of the canvas, and at least a readable editor when the window is wide.
Size _editorWindowSize(Size bounds) {
  const margin = 24.0;
  final maxWidth = math.max(0.0, bounds.width - margin * 2);
  final maxHeight = math.max(0.0, bounds.height - margin * 2);
  final width = math.min(maxWidth, math.max(880.0, bounds.width * 0.72));
  final height = math.min(maxHeight, math.max(640.0, bounds.height * 0.78));
  return Size(width, height);
}

const _editorFontSize = 13.0;
const _editorLineHeightFactor = 1.45;

/// One source line, forced so the gutter and the field stay on the same grid.
const _editorLineHeight = _editorFontSize * _editorLineHeightFactor;

const _editorPadding = EdgeInsets.fromLTRB(
  FanCadTokens.space2,
  FanCadTokens.space3,
  FanCadTokens.space3,
  FanCadTokens.space3,
);

const _editorStrut = StrutStyle(
  fontSize: _editorFontSize,
  height: _editorLineHeightFactor,
  leading: 0,
  forceStrutHeight: true,
  fontFamily: FanCadTokens.monoFontFamily,
);

TextStyle _editorStyle(FanCadTokens tokens) {
  return tokens.monoStyle.copyWith(
    fontSize: _editorFontSize,
    height: _editorLineHeightFactor,
  );
}

class _JsSourceController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final tokens = context.tokens;
    final spans = highlightJavaScript(
      text,
      plain: base.copyWith(color: tokens.text),
      keyword: base.copyWith(color: tokens.accent),
      string: base.copyWith(color: tokens.success),
      comment: base.copyWith(color: tokens.textMuted),
      number: base.copyWith(color: tokens.warning),
    );
    final composing = value.composing;
    final shown = !withComposing || !composing.isValid || composing.isCollapsed
        ? spans
        : _underline(spans, composing, base);
    if (shown.isEmpty) return TextSpan(style: base, text: '');
    return TextSpan(style: base, children: shown);
  }

  List<TextSpan> _underline(
    List<TextSpan> spans,
    TextRange range,
    TextStyle base,
  ) {
    final out = <TextSpan>[];
    var cursor = 0;
    for (final span in spans) {
      final chunk = span.text ?? '';
      final start = cursor;
      final end = cursor + chunk.length;
      cursor = end;
      if (chunk.isEmpty || end <= range.start || start >= range.end) {
        out.add(span);
        continue;
      }
      final style = span.style ?? base;
      void add(int from, int to, {bool mark = false}) {
        if (from >= to) return;
        out.add(
          TextSpan(
            text: chunk.substring(from - start, to - start),
            style: mark
                ? style.copyWith(decoration: TextDecoration.underline)
                : style,
          ),
        );
      }

      add(start, math.max(start, range.start));
      add(math.max(start, range.start), math.min(end, range.end), mark: true);
      add(math.min(end, range.end), end);
    }
    return out;
  }
}

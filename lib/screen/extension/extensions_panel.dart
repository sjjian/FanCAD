import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/extension/commands.dart';
import '../../l10n/l10n.dart';
import '../../services/extension.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'js_highlight.dart';

/// Saved extensions. One row is one `.js` file. Tapping the row opens it. The
/// configure menu enables, disables, or deletes it. A disabled extension stays in
/// the list and leaves the command line. The last failure stays on the row
/// until the next run.
class ExtensionsPanel extends ConsumerStatefulWidget {
  const ExtensionsPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

class _ExtensionsPanelState extends ConsumerState<ExtensionsPanel> {
  List<({String name, String? description, String? error, bool enabled})>
  _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    final result = await widget.workspace.runHeadless('extensions.list');
    if (!mounted) return;
    final raw = result.data?['extensions'];
    final scripts =
        <({String name, String? description, String? error, bool enabled})>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is! String || name.isEmpty) continue;
        scripts.add((
          name: name,
          description: _text(item['description']),
          error: _text(item['error']),
          enabled: item['enabled'] != false,
        ));
      }
    }
    setState(() => _entries = scripts);
  }

  String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(extensionNotifierProvider.select((model) => model.epoch), (
      _,
      _,
    ) {
      unawaited(_reload());
    });
    final directory = ref.watch(
      extensionNotifierProvider.select((model) => model.directory),
    );
    final available = directory.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: context.l10n.extensions,
          actions: [
            if (available)
              FanCadIconButton(
                icon: Icons.folder_open_outlined,
                tooltip: context.l10n.open_extensions_folder,
                onPressed: () =>
                    _openExtensionsFolder(widget.workspace, directory),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.add,
                tooltip: context.l10n.new_extension,
                onPressed: () => unawaited(_create()),
              ),
          ],
        ),
        Expanded(
          child: !available
              ? FanCadEmpty(message: context.l10n.extensions_unavailable)
              : _entries.isEmpty
              ? FanCadEmpty(
                  message: context.l10n.no_extensions,
                  actionLabel: context.l10n.new_extension,
                  onAction: () => unawaited(_create()),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final script = _entries[index];
                    return _ExtensionRow(
                      name: script.name,
                      description: script.description,
                      error: script.error,
                      enabled: script.enabled,
                      onOpen: () => unawaited(_edit(script.name)),
                      onEnable: (enabled) => ref
                          .read(extensionNotifierProvider.notifier)
                          .setEnabled(script.name, enabled),
                      onDelete: () => unawaited(_delete(script.name)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = await _askName(context);
    if (name == null || name.trim().isEmpty || !mounted) return;
    await widget.workspace.run(
      'extensions.write',
      args: {'name': name.trim(), 'content': extensionTemplate},
    );
    if (!mounted) return;
    await _edit(name.trim());
  }

  Future<void> _delete(String name) async {
    await widget.workspace.run('extensions.delete', args: {'name': name});
  }

  Future<void> _edit(String name) async {
    await _showExtensionDialog(
      context,
      _ExtensionEditor(name: name, workspace: widget.workspace),
    );
  }
}

enum _ExtensionMenuAction { enable, disable, delete }

class _ExtensionRow extends StatefulWidget {
  const _ExtensionRow({
    required this.name,
    required this.description,
    required this.error,
    required this.enabled,
    required this.onOpen,
    required this.onEnable,
    required this.onDelete,
  });

  final String name;
  final String? description;
  final String? error;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool> onEnable;
  final VoidCallback onDelete;

  @override
  State<_ExtensionRow> createState() => _ExtensionRowState();
}

class _ExtensionRowState extends State<_ExtensionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final titleColor = widget.enabled ? tokens.text : tokens.textMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered ? tokens.hover : Colors.transparent,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          padding: const EdgeInsets.fromLTRB(
            FanCadTokens.space3,
            FanCadTokens.space2,
            FanCadTokens.space1,
            FanCadTokens.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: tokens.bodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.enabled) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(l10n.extension_disabled, style: tokens.labelStyle),
                    ],
                    if (widget.description != null) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(
                        widget.description!,
                        style: tokens.labelStyle.copyWith(color: titleColor),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.error != null) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(
                        widget.error!,
                        style: tokens.labelStyle.copyWith(color: tokens.danger),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              FanCadMenuButton<_ExtensionMenuAction>(
                key: Key('extension-configure-${widget.name}'),
                tooltip: l10n.configure_extension,
                placement: FanCadMenuPlacement.auto,
                onSelected: (action) {
                  switch (action) {
                    case _ExtensionMenuAction.enable:
                      widget.onEnable(true);
                    case _ExtensionMenuAction.disable:
                      widget.onEnable(false);
                    case _ExtensionMenuAction.delete:
                      widget.onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (!widget.enabled)
                    fanCadMenuItem(
                      context,
                      value: _ExtensionMenuAction.enable,
                      label: l10n.enable_extension,
                      icon: Icons.play_arrow_outlined,
                    ),
                  if (widget.enabled)
                    fanCadMenuItem(
                      context,
                      value: _ExtensionMenuAction.disable,
                      label: l10n.disable_extension,
                      icon: Icons.pause_outlined,
                    ),
                  fanCadMenuItem(
                    context,
                    value: _ExtensionMenuAction.delete,
                    label: l10n.delete_extension,
                    icon: Icons.delete_outline,
                  ),
                ],
                child: const _ExtensionGear(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionGear extends StatefulWidget {
  const _ExtensionGear();

  @override
  State<_ExtensionGear> createState() => _ExtensionGearState();
}

class _ExtensionGearState extends State<_ExtensionGear> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hovered ? tokens.pressed : Colors.transparent,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
        ),
        child: Icon(
          Icons.settings_outlined,
          size: FanCadTokens.iconMedium,
          color: _hovered ? tokens.text : tokens.textMuted,
        ),
      ),
    );
  }
}

class _ExtensionEditor extends ConsumerStatefulWidget {
  const _ExtensionEditor({required this.name, required this.workspace});

  final String name;
  final Workspace workspace;

  @override
  ConsumerState<_ExtensionEditor> createState() => _ExtensionEditorState();
}

class _ExtensionEditorState extends ConsumerState<_ExtensionEditor> {
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
      setState(() => _error = result.message);
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
    final result = await widget.workspace.runHeadless(
      'extensions.write',
      args: {'name': widget.name, 'content': _body.text},
    );
    if (!mounted) return;
    setState(() {
      _dirty = !result.isOk;
      _error = result.isOk ? null : result.message;
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
          title: Text(context.l10n.unsaved_editor_changes),
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
                  _LineGutter(
                    controller: _body,
                    scroll: _scroll,
                    style: _editorStyle(tokens),
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
                        contentPadding: EdgeInsets.fromLTRB(
                          FanCadTokens.space2,
                          FanCadTokens.space3,
                          FanCadTokens.space3,
                          FanCadTokens.space3,
                        ),
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

Future<void> _showExtensionDialog(BuildContext context, Widget child) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => child,
  );
}

Future<String?> _askName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: context.tokens.surfaceOverlay,
        title: Text(context.l10n.new_extension),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.prompt_extension_name,
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
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

/// Line numbers for the extension source. They share the field's scroll offset
/// and the same strut, so a number stays beside its line.
class _LineGutter extends StatelessWidget {
  const _LineGutter({
    required this.controller,
    required this.scroll,
    required this.style,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, scroll]),
      builder: (context, _) {
        final text = controller.text;
        final count = text.isEmpty ? 1 : text.split('\n').length;
        final active = _caretLine(controller.value);
        final digits = math.max(2, '$count'.length);
        final probe = TextPainter(
          text: TextSpan(text: '0' * digits, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final width = probe.width + FanCadTokens.space2 * 2;
        probe.dispose();
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        // InputDecorator shifts the field by half the visual-density adjustment,
        // so the numbers use that same inset or they sit a step below the text.
        final top =
            FanCadTokens.space3 +
            Theme.of(context).visualDensity.baseSizeAdjustment.dy / 2;
        return DecoratedBox(
          key: const Key('extension-editor-lines'),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: tokens.border)),
          ),
          child: SizedBox(
            width: width,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topRight,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Transform.translate(
                    offset: Offset(0, -offset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var line = 1; line <= count; line++)
                          SizedBox(
                            height: _editorLineHeight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: FanCadTokens.space2,
                              ),
                              child: Text(
                                '$line',
                                textAlign: TextAlign.right,
                                style: line == active
                                    ? style.copyWith(color: tokens.text)
                                    : style.copyWith(color: tokens.textMuted),
                                strutStyle: _editorStrut,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

int _caretLine(TextEditingValue value) {
  if (!value.selection.isValid) return 1;
  final end = value.selection.extentOffset.clamp(0, value.text.length);
  return '\n'.allMatches(value.text.substring(0, end)).length + 1;
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

Future<void> _openExtensionsFolder(Workspace workspace, String path) async {
  try {
    await Directory(path).create(recursive: true);
    if (Platform.isMacOS) {
      await Process.start('open', [path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [path]);
    } else {
      await Process.start('xdg-open', [path]);
    }
  } catch (error) {
    workspace.notify(
      lookupAppLocalizations(const Locale('en')).could_not_open(path, '$error'),
      isError: true,
    );
  }
}

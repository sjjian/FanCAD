import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../services/workspace.dart';
import 'tokens.dart';
import 'widgets.dart';

/// The custom title bar.
///
/// Replaces the OS chrome so search, window buttons and the assistant
/// toggle share one 32-pixel row. New and open live on the start page;
/// save and drawing tools live on the canvas.
///
/// macOS keeps the native traffic lights on a hidden title bar, so the first
/// icon is inset and the Windows-style buttons stay off that platform.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.onTogglePalette,
    required this.onToggleAssistant,
    this.assistantOpen = false,
  });

  final VoidCallback onTogglePalette;
  final VoidCallback onToggleAssistant;
  final bool assistantOpen;

  /// Space before the first title-bar control.
  ///
  /// The native traffic lights sit over the Flutter view; without this inset
  /// the drag area starts under the red button.
  @visibleForTesting
  static double leadingInset({required bool usesNativeTrafficLights}) =>
      usesNativeTrafficLights
      ? FanCadTokens.macTrafficLightsWidth
      : FanCadTokens.space2;

  /// Space after the last title-bar control.
  ///
  /// macOS has no window-button cluster on the right, so the assistant
  /// icon would otherwise sit flush against the window edge. Caption
  /// buttons already end on the window edge, so that cluster takes no inset.
  @visibleForTesting
  static double trailingInset({required bool usesNativeTrafficLights}) =>
      usesNativeTrafficLights ? FanCadTokens.space2 : 0;

  /// Whether this platform draws its own minimise / maximise / close cluster.
  @visibleForTesting
  static bool usesCustomWindowButtons({
    required bool usesNativeTrafficLights,
  }) => !usesNativeTrafficLights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final nativeLights = Platform.isMacOS;

    return SizedBox(
      key: const Key('title-bar'),
      height: FanCadTokens.titleBarHeight,
      child: DecoratedBox(
        // Foreground so the seam stays visible and the row keeps its full height.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.borderMuted)),
        ),
        child: ColoredBox(
          color: tokens.surfaceRaised,
          child: Row(
            children: [
              SizedBox(
                width: leadingInset(usesNativeTrafficLights: nativeLights),
              ),
              const Expanded(child: _DragArea(child: SizedBox.expand())),
              FanCadIconButton(
                icon: Icons.search,
                tooltip:
                    '${l10n.command_palette}  ${formatKeybinding('ctrl+shift+p')}',
                onPressed: onTogglePalette,
              ),
              FanCadIconButton(
                icon: Icons.auto_awesome_outlined,
                tooltip: assistantOpen
                    ? l10n.hide_assistant
                    : l10n.show_assistant,
                isActive: assistantOpen,
                onPressed: onToggleAssistant,
              ),
              if (usesCustomWindowButtons(
                usesNativeTrafficLights: nativeLights,
              ))
                const _WindowButtons(),
              SizedBox(
                width: trailingInset(usesNativeTrafficLights: nativeLights),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The document tab strip.
class DocumentTabStrip extends ConsumerWidget {
  const DocumentTabStrip({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strip = ref.watch(
      workspaceNotifierProvider.select((s) => s.tabStrip),
    );
    final tokens = context.tokens;
    final tabs = workspace.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    return Container(
      height: FanCadTokens.tabBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.borderMuted)),
      ),
      child: Row(
        children: [
          Flexible(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: tabs.length,
              itemBuilder: (context, index) => _Tab(
                workspace: workspace,
                tab: tabs[index],
                isActive: index == strip.activeIndex,
                onTap: () => workspace.activate(index),
                onClose: () {
                  if (workspace.closeTab(index)) return;
                  workspace.activate(index);
                  workspace.run('file.close');
                },
              ),
            ),
          ),
          FanCadIconButton(
            key: const Key('document-new-tab'),
            icon: Icons.add,
            tooltip: context.l10n.new_tab,
            onPressed: workspace.openStartTab,
          ),
          if (tabs.length > 1)
            _OpenDrawingsMenu(
              workspace: workspace,
              activeIndex: strip.activeIndex,
            ),
          const SizedBox(width: FanCadTokens.space1),
        ],
      ),
    );
  }
}

/// The strip scrolls; this list does not. A drawing that has gone off the
/// right edge is still one click away.
class _OpenDrawingsMenu extends StatelessWidget {
  const _OpenDrawingsMenu({required this.workspace, required this.activeIndex});

  final Workspace workspace;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tabs = workspace.tabs;
    return FanCadMenuButton<int>(
      tooltip: context.l10n.open_drawings(tabs.length),
      placement: FanCadMenuPlacement.down,
      onSelected: workspace.activate,
      itemBuilder: (context) => [
        for (var i = 0; i < tabs.length; i++)
          fanCadMenuItem<int>(
            context,
            value: i,
            label: tabs[i].isStartPage ? context.l10n.start_tab : tabs[i].title,
            labelChild: tabs[i].isStartPage
                ? null
                : FileName(
                    name: tabs[i].title,
                    maxWidth: 280,
                    style: tokens.bodyStyle,
                  ),
            checked: i == activeIndex ? true : null,
            leading: i == activeIndex
                ? null
                : tabs[i].isDirty
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
      child: SizedBox(
        width: 22,
        height: 28,
        child: Icon(
          Icons.arrow_drop_down,
          size: FanCadTokens.iconMedium,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.workspace,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final Workspace workspace;
  final DocumentTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = widget.tab;
    return FanCadTab(
      key: Key('document-tab-${tab.session.id}'),
      selected: widget.isActive,
      onTap: widget.onTap,
      onClose: widget.onClose,
      onSecondaryTapDown: (position) {
        widget.onTap();
        _openMenu(position);
      },
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      child: Row(
        children: [
          if (tab.diagnostics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space1),
              child: GestureDetector(
                onTap: () => _showImportWarnings(),
                child: Tooltip(
                  message: context.l10n.import_warnings_tooltip(
                    tab.diagnostics.length,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: FanCadTokens.iconSmall,
                    color: tokens.warning,
                  ),
                ),
              ),
            ),
          Tooltip(
            message: tab.isDirty
                ? tab.filePath == null
                      ? context.l10n.unsaved_drawing
                      : context.l10n.unsaved_changes_path(tab.filePath!)
                : tab.filePath ?? context.l10n.unsaved_drawing,
            waitDuration: const Duration(milliseconds: 500),
            child: FileName(
              name: tab.isStartPage ? context.l10n.start_tab : tab.title,
              maxWidth: 180,
              style: tokens.bodyStyle.copyWith(
                color: widget.isActive ? tokens.text : tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: FanCadTokens.space2),
          // The unsaved dot becomes the close button on hover, which keeps
          // the tab width from jumping as the pointer moves across it.
          SizedBox(
            width: 18,
            child: _hovered || widget.isActive
                ? FanCadIconButton(
                    icon: Icons.close,
                    size: 18,
                    iconSize: FanCadTokens.iconSmall,
                    tooltip: tab.isDirty
                        ? '${context.l10n.close_unsaved}  ${shortcutLabelForCommand(widget.workspace.commands, 'file.close')}'
                        : '${context.l10n.close}  ${shortcutLabelForCommand(widget.workspace.commands, 'file.close')}',
                    onPressed: widget.onClose,
                  )
                : tab.isDirty
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(Offset globalPosition) async {
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final tab = widget.tab;
    final others = workspace.tabs.length > 1;
    final path = tab.filePath;
    final chosen = await showFanCadMenu<String>(
      context: context,
      position: fanCadMenuPosition(globalPosition),
      items: [
        fanCadMenuItem(context, value: 'close', label: l10n.close),
        fanCadMenuItem(
          context,
          value: 'closeOthers',
          label: l10n.close_others,
          enabled: others,
        ),
        fanCadMenuItem(context, value: 'closeAll', label: l10n.close_all),
        if (path != null || tab.diagnostics.isNotEmpty) ...[
          const PopupMenuDivider(),
          if (path != null)
            fanCadMenuItem(context, value: 'copyPath', label: l10n.copy_path),
          if (path != null)
            fanCadMenuItem(
              context,
              value: 'reveal',
              label: l10n.revealInFolder(),
            ),
          if (tab.diagnostics.isNotEmpty)
            fanCadMenuItem(
              context,
              value: 'warnings',
              label: l10n.import_warnings(tab.diagnostics.length),
            ),
        ],
      ],
    );
    if (!mounted) return;
    switch (chosen) {
      case 'close':
        widget.onClose();
      case 'closeOthers':
        await workspace.closeOtherTabs(tab);
      case 'closeAll':
        await workspace.closeAllTabs();
      case 'copyPath':
        if (path == null) return;
        await Clipboard.setData(ClipboardData(text: path));
        workspace.notify(l10n.copied_path(path));
      case 'reveal':
        if (path == null) return;
        await _revealOnDisk(path, l10n);
      case 'warnings':
        await _showImportWarnings();
    }
  }

  Future<void> _revealOnDisk(String path, AppLocalizations l10n) async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', path]);
      } else {
        await Process.start('xdg-open', [File(path).parent.path]);
      }
    } catch (error) {
      widget.workspace.notify(
        l10n.could_not_reveal(path, '$error'),
        isError: true,
      );
    }
  }

  Future<void> _showImportWarnings() async {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final diagnostics = widget.tab.diagnostics;
    if (diagnostics.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AlertDialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        title: Text(
          l10n.importWarningTitle(diagnostics.length),
          style: tokens.bodyStyle.copyWith(fontSize: 15),
        ),
        content: SizedBox(
          width: 480,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final line in diagnostics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
                    child: Text(line, style: tokens.labelStyle),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diagnostics.join('\n')));
              widget.workspace.notify(l10n.copied_warnings(diagnostics.length));
              Navigator.of(context).pop();
            },
            child: Text(l10n.copy_all, style: tokens.bodyStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// The area of the title bar that drags the window.
class _DragArea extends StatelessWidget {
  const _DragArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => windowManager.startDragging(),
    onDoubleTap: () async {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    },
    child: child,
  );
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool _maximized = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bind());
  }

  Future<void> _bind() async {
    try {
      windowManager.addListener(this);
      _listening = true;
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {
      // Headless tests have no window plugin.
    }
  }

  @override
  void dispose() {
    if (_listening) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => _setMaximized(true);

  @override
  void onWindowUnmaximize() => _setMaximized(false);

  void _setMaximized(bool value) {
    if (!mounted || _maximized == value) return;
    setState(() => _maximized = value);
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        _CaptionButton(
          key: const Key('window-minimize'),
          glyph: _CaptionGlyph.minimize,
          tooltip: l10n.minimise,
          onPressed: windowManager.minimize,
        ),
        _CaptionButton(
          key: const Key('window-maximize'),
          glyph: _maximized ? _CaptionGlyph.restore : _CaptionGlyph.maximize,
          tooltip: _maximized ? l10n.restore : l10n.maximise,
          onPressed: _toggleMaximize,
        ),
        _CaptionButton(
          key: const Key('window-close'),
          glyph: _CaptionGlyph.close,
          tooltip: l10n.close_window,
          close: true,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

/// A full-height caption button. The hit target is a square-cornered
/// rectangle the height of the title bar, the way Chrome draws minimise,
/// maximise and close, rather than a rounded toolbar icon.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.close = false,
  });

  final _CaptionGlyph glyph;
  final String tooltip;
  final VoidCallback onPressed;

  /// Close fills with the Windows caption red and turns the glyph white.
  final bool close;

  /// Windows and Chrome use a 46px caption button at 96 dpi.
  static const double width = 46;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fill = _fill(tokens);
    final glyph = widget.close && (_hovered || _pressed)
        ? Colors.white
        : tokens.text;
    // The restore glyph punches out the rear square. Idle buttons are
    // transparent, so that punch uses the title-bar surface.
    final punch = fill == Colors.transparent ? tokens.surfaceRaised : fill;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: SizedBox(
            width: _CaptionButton.width,
            height: FanCadTokens.titleBarHeight,
            child: ColoredBox(
              color: fill,
              child: CustomPaint(
                painter: _CaptionGlyphPainter(
                  glyph: widget.glyph,
                  color: glyph,
                  background: punch,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Minimise and maximise wash the whole button. Close uses the caption
  /// red Chrome shows on Windows, darker while the pointer is down.
  Color _fill(FanCadTokens tokens) {
    if (widget.close) {
      if (_pressed) return const Color(0xFFC50F1F);
      if (_hovered) return const Color(0xFFE81123);
      return Colors.transparent;
    }
    if (_pressed) {
      return tokens.isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.10);
    }
    if (_hovered) {
      return tokens.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
    }
    return Colors.transparent;
  }
}

enum _CaptionGlyph { minimize, maximize, restore, close }

/// 1px caption glyphs: a dash, a square, two offset squares, or an X.
class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter({
    required this.glyph,
    required this.color,
    required this.background,
  });

  final _CaptionGlyph glyph;
  final Color color;
  final Color background;

  static const double _extent = 10;
  static const double _stroke = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    final center = Offset(size.width / 2, size.height / 2);
    switch (glyph) {
      case _CaptionGlyph.minimize:
        canvas.drawLine(
          Offset(center.dx - _extent / 2, center.dy),
          Offset(center.dx + _extent / 2, center.dy),
          paint,
        );
      case _CaptionGlyph.maximize:
        canvas.drawRect(_square(center, _extent), paint);
      case _CaptionGlyph.restore:
        _paintRestore(canvas, center, paint);
      case _CaptionGlyph.close:
        final box = _square(center, _extent);
        canvas.drawLine(box.topLeft, box.bottomRight, paint);
        canvas.drawLine(box.topRight, box.bottomLeft, paint);
    }
  }

  /// Rear square up and to the right, front square punched over it.
  void _paintRestore(Canvas canvas, Offset center, Paint stroke) {
    const box = 8.0;
    const shift = 1.0;
    final back = _square(center + const Offset(shift, -shift), box);
    final front = _square(center + const Offset(-shift, shift), box);
    canvas.drawRect(back, stroke);
    canvas.drawRect(front, Paint()..color = background);
    canvas.drawRect(front, stroke);
  }

  Rect _square(Offset center, double extent) =>
      Rect.fromCenter(center: center, width: extent, height: extent);

  @override
  bool shouldRepaint(covariant _CaptionGlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.background != background;
}

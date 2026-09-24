import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../services/workspace.dart';
import '../widgets/file_name.dart';
import '../widgets/icon_button.dart';
import '../widgets/row.dart';
import '../widgets/tokens.dart';

/// The empty state shown when no drawing is open.
class EmptyWorkspace extends ConsumerWidget {
  const EmptyWorkspace({
    super.key,
    required this.onOpenRecent,
    required this.onOpen,
    required this.onNew,
    required this.onShowCommands,
  });

  final ValueChanged<String> onOpenRecent;
  final VoidCallback onOpen;
  final VoidCallback onNew;
  final VoidCallback onShowCommands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentFiles = ref.watch(
      workspaceNotifierProvider.select((s) => s.recentFiles),
    );
    final tokens = context.tokens;
    return Container(
      color: tokens.canvas,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space5,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/logo.png',
                      width: 40,
                      height: 40,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 40, height: 40),
                    ),
                    const SizedBox(width: FanCadTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FanCAD',
                            style: tokens.dialogTitleStyle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: FanCadTokens.space1),
                          Text(
                            context.l10n.empty_tagline,
                            style: tokens.labelStyle.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FanCadTokens.space5),
                Row(
                  children: [
                    _StartAction(
                      key: const Key('empty-workspace-new'),
                      icon: Icons.insert_drive_file_outlined,
                      tooltip:
                          '${context.l10n.new_drawing}  ${formatKeybinding('ctrl+n')}',
                      emphasized: true,
                      onPressed: onNew,
                    ),
                    const SizedBox(width: FanCadTokens.space3),
                    _StartAction(
                      key: const Key('empty-workspace-open'),
                      icon: Icons.folder_open_outlined,
                      tooltip:
                          '${context.l10n.open_drawing_file}  ${formatKeybinding('ctrl+o')}',
                      onPressed: onOpen,
                    ),
                    const SizedBox(width: FanCadTokens.space3),
                    _StartAction(
                      key: const Key('empty-workspace-commands'),
                      icon: Icons.search,
                      tooltip:
                          '${context.l10n.show_all_commands}  ${formatKeybinding('ctrl+shift+p')}',
                      onPressed: onShowCommands,
                    ),
                    const Spacer(),
                    _StartAction(
                      key: const Key('empty-workspace-github'),
                      iconBuilder: (color) => _GithubMark(color: color),
                      tooltip: context.l10n.empty_github,
                      onPressed: () =>
                          unawaited(_openInBrowser(_githubRepoUrl)),
                    ),
                  ],
                ),
                if (recentFiles.isNotEmpty) ...[
                  const SizedBox(height: FanCadTokens.space5),
                  Text(
                    context.l10n.recent.toUpperCase(),
                    style: tokens.sectionTitleStyle,
                  ),
                  const SizedBox(height: FanCadTokens.space2),
                  for (final path in recentFiles.take(8))
                    _Recent(path: path, onPressed: () => onOpenRecent(path)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartAction extends StatefulWidget {
  const _StartAction({
    super.key,
    this.icon,
    this.iconBuilder,
    required this.tooltip,
    required this.onPressed,
    this.emphasized = false,
  }) : assert(icon != null || iconBuilder != null);

  final IconData? icon;
  final Widget Function(Color color)? iconBuilder;
  final String tooltip;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  State<_StartAction> createState() => _StartActionState();
}

class _StartActionState extends State<_StartAction> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fill = widget.emphasized
        ? tokens.accent
        : _hovered
        ? tokens.hover
        : Colors.transparent;
    final iconColor = widget.emphasized ? tokens.accentText : tokens.textMuted;
    final borderColor = widget.emphasized ? tokens.accent : tokens.border;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (show) => setState(() => _hovered = show),
        onShowFocusHighlight: (show) => setState(() => _focused = show),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
              border: Border.all(
                color: _focused ? tokens.focusRing : borderColor,
                width: _focused ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child:
                widget.iconBuilder?.call(iconColor) ??
                Icon(
                  widget.icon,
                  size: FanCadTokens.iconLarge,
                  color: iconColor,
                ),
          ),
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.path, required this.onPressed});

  final String path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final separator = path.contains(r'\') ? r'\' : '/';
    final parts = path.split(separator);
    final name = parts.isEmpty ? path : parts.last;
    final folder = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join(separator)
        : '';
    final missing = !File(path).existsSync();
    final l10n = context.l10n;
    return Tooltip(
      message: missing ? l10n.missing_path(path) : path,
      waitDuration: const Duration(milliseconds: 400),
      child: FanCadRow(
        onTap: onPressed,
        onSecondaryTap: missing ? null : () => _revealOnDisk(path),
        height: 30,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Icon(
              missing
                  ? Icons.broken_image_outlined
                  : Icons.insert_drive_file_outlined,
              size: FanCadTokens.iconMedium,
              color: missing ? tokens.textFaint : tokens.textMuted,
            ),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: _RecentLabel(
                name: name,
                folder: missing ? l10n.missing_folder(folder) : folder,
                nameStyle: tokens.bodyStyle.copyWith(
                  color: missing ? tokens.textFaint : tokens.text,
                  decoration: missing ? TextDecoration.lineThrough : null,
                ),
                folderStyle: tokens.labelStyle,
              ),
            ),
            if (!missing)
              FanCadIconButton(
                icon: Icons.folder_open_outlined,
                size: 20,
                iconSize: FanCadTokens.iconSmall,
                tooltip: l10n.revealInFolder(),
                onPressed: () => _revealOnDisk(path),
              ),
          ],
        ),
      ),
    );
  }
}

/// File name at its own width, folder path in whatever is left.
///
/// The reveal button sits outside this, so it stays on the row's right edge.
class _RecentLabel extends StatelessWidget {
  const _RecentLabel({
    required this.name,
    required this.folder,
    required this.nameStyle,
    required this.folderStyle,
  });

  final String name;
  final String folder;
  final TextStyle nameStyle;
  final TextStyle folderStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FileName(name: name, maxWidth: 200, style: nameStyle),
        if (folder.isNotEmpty) ...[
          const SizedBox(width: FanCadTokens.space2),
          Expanded(
            child: Text(
              folder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: folderStyle,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _revealOnDisk(String path) async {
  try {
    if (Platform.isMacOS) {
      await Process.start('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', ['/select,', path]);
    } else {
      await Process.start('xdg-open', [File(path).parent.path]);
    }
  } catch (_) {}
}

const _githubRepoUrl = 'https://github.com/sjjian/FanCAD';

Future<void> _openInBrowser(String url) async {
  try {
    if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', url]);
    } else {
      await Process.start('xdg-open', [url]);
    }
  } catch (_) {}
}

/// GitHub mark, Simple Icons path on a 24×24 viewBox.
class _GithubMark extends StatelessWidget {
  const _GithubMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(FanCadTokens.iconLarge),
      painter: _GithubMarkPainter(color),
    );
  }
}

class _GithubMarkPainter extends CustomPainter {
  const _GithubMarkPainter(this.color);

  final Color color;

  static final Path _mark = _githubMarkPath();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(_mark, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GithubMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

Path _githubMarkPath() {
  // M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12
  final path = Path()..moveTo(12, 0.297);
  path.relativeCubicTo(-6.63, 0, -12, 5.373, -12, 12);
  path.relativeCubicTo(0, 5.303, 3.438, 9.8, 8.205, 11.385);
  path.relativeCubicTo(0.6, 0.113, 0.82, -0.258, 0.82, -0.577);
  path.relativeCubicTo(0, -0.285, -0.01, -1.04, -0.015, -2.04);
  path.relativeCubicTo(-3.338, 0.724, -4.042, -1.61, -4.042, -1.61);
  path.cubicTo(4.422, 18.07, 3.633, 17.7, 3.633, 17.7);
  path.relativeCubicTo(-1.087, -0.744, 0.084, -0.729, 0.084, -0.729);
  path.relativeCubicTo(1.205, 0.084, 1.838, 1.236, 1.838, 1.236);
  path.relativeCubicTo(1.07, 1.835, 2.809, 1.305, 3.495, 0.998);
  path.relativeCubicTo(0.108, -0.776, 0.417, -1.305, 0.76, -1.605);
  path.relativeCubicTo(-2.665, -0.3, -5.466, -1.332, -5.466, -5.93);
  path.relativeCubicTo(0, -1.31, 0.465, -2.38, 1.235, -3.22);
  path.relativeCubicTo(-0.135, -0.303, -0.54, -1.523, 0.105, -3.176);
  path.relativeCubicTo(0, 0, 1.005, -0.322, 3.3, 1.23);
  path.relativeCubicTo(0.96, -0.267, 1.98, -0.399, 3, -0.405);
  path.relativeCubicTo(1.02, 0.006, 2.04, 0.138, 3, 0.405);
  path.relativeCubicTo(2.28, -1.552, 3.285, -1.23, 3.285, -1.23);
  path.relativeCubicTo(0.645, 1.653, 0.24, 2.873, 0.12, 3.176);
  path.relativeCubicTo(0.765, 0.84, 1.23, 1.91, 1.23, 3.22);
  path.relativeCubicTo(0, 4.61, -2.805, 5.625, -5.475, 5.92);
  path.relativeCubicTo(0.42, 0.36, 0.81, 1.096, 0.81, 2.22);
  path.relativeCubicTo(0, 1.606, -0.015, 2.896, -0.015, 3.286);
  path.relativeCubicTo(0, 0.315, 0.21, 0.69, 0.825, 0.57);
  path.cubicTo(20.565, 22.092, 24, 17.592, 24, 12.297);
  path.relativeCubicTo(0, -6.627, -5.373, -12, -12, -12);
  path.close();
  return path;
}

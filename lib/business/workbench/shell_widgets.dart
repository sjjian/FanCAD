import 'dart:io';

import 'package:flutter/material.dart';

import '../commands/keybindings.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../widgets/shell_icon_button.dart';
import '../widgets/shell_row.dart';

export '../widgets/shell_badge.dart';
export '../widgets/shell_banner.dart';
export '../widgets/shell_canvas_window.dart';
export '../widgets/shell_chip.dart';
export '../widgets/shell_empty.dart';
export '../widgets/shell_field.dart';
export '../widgets/shell_form.dart';
export '../widgets/shell_hairline.dart';
export '../widgets/shell_icon_button.dart';
export '../widgets/shell_menu.dart';
export '../widgets/shell_panel.dart';
export '../widgets/shell_row.dart';
export '../widgets/shell_splitter.dart';
export '../widgets/shell_tab.dart';
export '../widgets/shell_toggle.dart';

/// A modifier-aware shortcut label for chrome that mentions keystrokes.
String shellShortcut(String key, {bool shift = false}) {
  final prefix = Platform.isMacOS ? '⌘' : 'Ctrl';
  return shift ? '$prefix Shift $key' : '$prefix $key';
}

/// The empty state shown when no drawing is open.
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({
    super.key,
    required this.recentFiles,
    required this.onOpenRecent,
    required this.onOpen,
    required this.onNew,
    required this.onShowCommands,
  });

  final List<String> recentFiles;
  final ValueChanged<String> onOpenRecent;
  final VoidCallback onOpen;
  final VoidCallback onNew;
  final VoidCallback onShowCommands;

  @override
  Widget build(BuildContext context) {
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
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
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
            child: Icon(
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
      child: ShellRow(
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
            Text(
              name,
              style: tokens.bodyStyle.copyWith(
                color: missing ? tokens.textFaint : tokens.text,
                decoration: missing ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Text(
                missing ? l10n.missing_folder(folder) : folder,
                style: tokens.labelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!missing)
              ShellIconButton(
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

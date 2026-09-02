import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'shell_row.dart';

/// The header above a panel's contents.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: FanCadTokens.tabBarHeight,
      padding: const EdgeInsets.only(
        left: FanCadTokens.space3,
        right: FanCadTokens.space1,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderMuted)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tokens.sectionTitleStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A labelled section inside a panel.
class PanelSection extends StatelessWidget {
  const PanelSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: FanCadTokens.space3,
            right: FanCadTokens.space2,
            top: FanCadTokens.space3,
            bottom: FanCadTokens.space1,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: tokens.sectionTitleStyle)),
              ?trailing,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// A name and value on one line, as the properties panel uses.
class PropertyRow extends StatelessWidget {
  const PropertyRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.isEditable = false,
    this.copyText,
    this.onCopied,
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;
  final bool isEditable;

  /// Copied on right-click, or on a left-click when the row is not editable.
  final String? copyText;
  final ValueChanged<String>? onCopied;

  void _copy(BuildContext context) {
    final text = copyText;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    onCopied?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tooltip = onTap != null
        ? context.l10n.click_to_change(label)
        : copyText != null
        ? context.l10n.click_to_copy_label(label)
        : null;
    Widget row = ShellRow(
      onTap: onTap ?? (copyText == null ? null : () => _copy(context)),
      onSecondaryTap: copyText == null ? null : () => _copy(context),
      height: FanCadTokens.rowHeight,
      padding: const EdgeInsets.only(left: FanCadTokens.space3, right: 4),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: tokens.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: DefaultTextStyle(
              style: tokens.monoStyle.copyWith(
                color: isEditable ? tokens.text : tokens.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: value,
            ),
          ),
          if (isEditable)
            Icon(
              Icons.chevron_right,
              size: FanCadTokens.iconSmall,
              color: tokens.textFaint,
            ),
        ],
      ),
    );
    if (tooltip == null) return row;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: row,
    );
  }
}

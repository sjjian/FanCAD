import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'shell_hairline.dart';

/// A labelled group inside the settings dialog.
///
/// Title plus a hairline, the same desktop form language as OpenHare: the
/// heading is a sentence, not an uppercase chrome label, so it reads as a
/// section rather than another tab.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: tokens.bodyStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: FanCadTokens.space2),
        const ShellHairline(),
        const SizedBox(height: FanCadTokens.space3),
        ...children,
      ],
    );
  }
}

/// A muted label on the left and a control on the right.
class SettingsLabeledRow extends StatelessWidget {
  const SettingsLabeledRow({
    super.key,
    required this.label,
    required this.child,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  static const double labelWidth = 128;

  final String label;
  final Widget child;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space1),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Text(
                label,
                style: tokens.labelStyle.copyWith(color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A mutually exclusive card with a radio mark.
class SettingsRadioOption extends StatefulWidget {
  const SettingsRadioOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = defaultWidth,
  });

  static const double defaultWidth = 136;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  State<SettingsRadioOption> createState() => _SettingsRadioOptionState();
}

class _SettingsRadioOptionState extends State<SettingsRadioOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
              vertical: FanCadTokens.space2,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? tokens.selection
                  : _hovered
                  ? tokens.hover
                  : tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
              border: Border.all(
                color: widget.selected ? tokens.accent : tokens.borderStrong,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: FanCadTokens.iconSmall,
                  color: widget.selected ? tokens.accent : tokens.textMuted,
                ),
                const SizedBox(width: FanCadTokens.space2),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.bodyStyle.copyWith(
                      color: widget.selected ? tokens.text : tokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled row with a compact Material switch on the right.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.tooltip,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? description;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget control = SizedBox(
      height: 22,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      control = Tooltip(message: tooltip, child: control);
    }
    return SettingsLabeledRow(
      label: label,
      child: Row(
        children: [
          if (description != null)
            Expanded(
              child: Text(
                description!,
                style: tokens.labelStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          control,
        ],
      ),
    );
  }
}

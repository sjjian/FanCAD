import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'shell_hairline.dart';
import 'shell_menu.dart';

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

  /// Space after the section rule and between each stacked control.
  static const double itemGap = FanCadTokens.space4;

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
        const SizedBox(height: SettingsSection.itemGap),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: SettingsSection.itemGap),
          children[i],
        ],
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

  static const double labelWidth = 140;

  final String label;
  final Widget child;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
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
    );
  }
}

/// One row in a [SettingsDropdown].
class SettingsDropdownOption<T> {
  const SettingsDropdownOption({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

/// An outlined menu field matching [SettingsTextField].
class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<SettingsDropdownOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    SettingsDropdownOption<T>? current;
    for (final option in options) {
      if (option.value == value) {
        current = option;
        break;
      }
    }
    current ??= options.isEmpty ? null : options.first;
    return ShellMenuButton<T>(
      placement: ShellMenuPlacement.down,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          shellMenuItem(
            context,
            key: option.key,
            value: option.value,
            label: option.label,
            checked: option.value == value,
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
                current?.label ?? '',
                style: tokens.bodyStyle,
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
      child: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
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

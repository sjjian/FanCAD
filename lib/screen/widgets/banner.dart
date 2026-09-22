import 'package:flutter/material.dart';

import 'icon_button.dart';
import 'tokens.dart';

/// Tone for a [FanCadBanner] or [FanCadToast] edge.
enum FanCadTone { info, warning, danger, success }

/// A full-width alert strip or inset error card.
class FanCadBanner extends StatelessWidget {
  const FanCadBanner({
    super.key,
    required this.message,
    required this.tone,
    this.icon,
    this.action,
    this.onAction,
    this.onDismiss,
    this.inset = false,
  });

  final String message;
  final FanCadTone tone;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (tone) {
      FanCadTone.info => tokens.accent,
      FanCadTone.warning => tokens.warning,
      FanCadTone.danger => tokens.danger,
      FanCadTone.success => tokens.success,
    };
    if (inset) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
          FanCadTokens.space2,
          0,
          FanCadTokens.space2,
          FanCadTokens.space2,
        ),
        padding: const EdgeInsets.only(left: FanCadTokens.space3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon ?? Icons.error_outline, size: 14, color: color),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FanCadTokens.space2,
                ),
                child: Text(
                  message,
                  style: tokens.labelStyle.copyWith(color: color),
                ),
              ),
            ),
            if (onDismiss != null)
              FanCadIconButton(
                icon: Icons.close,
                size: 20,
                iconSize: FanCadTokens.iconSmall,
                onPressed: onDismiss,
              ),
          ],
        ),
      );
    }
    return Material(
      color: color.withValues(alpha: tokens.isDark ? 0.16 : 0.12),
      child: Container(
        height: FanCadTokens.tabBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: FanCadTokens.iconMedium, color: color),
              const SizedBox(width: FanCadTokens.space2),
            ],
            Expanded(
              child: Text(
                message,
                style: tokens.bodyStyle.copyWith(color: tokens.text),
              ),
            ),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}

/// A floating notice card. Timing and queue stay with the workspace.
class FanCadToast extends StatelessWidget {
  const FanCadToast({
    super.key,
    required this.message,
    required this.tone,
    this.onTap,
    this.onDismiss,
    this.tapTooltip,
    this.dismissTooltip,
  });

  final String message;
  final FanCadTone tone;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final String? tapTooltip;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (tone) {
      FanCadTone.danger => tokens.danger,
      FanCadTone.success => tokens.success,
      FanCadTone.warning => tokens.warning,
      FanCadTone.info => tokens.accent,
    };
    final icon = switch (tone) {
      FanCadTone.danger => Icons.error_outline,
      FanCadTone.success => Icons.check_circle_outline,
      FanCadTone.warning => Icons.warning_amber_outlined,
      FanCadTone.info => Icons.info_outline,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: tokens.surfaceOverlay,
        elevation: 3,
        shadowColor: tokens.shadow,
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space3,
            vertical: FanCadTokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FanCadTokens.radius),
            border: Border.all(color: color),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: FanCadTokens.iconMedium, color: color),
              const SizedBox(width: FanCadTokens.space2),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Tooltip(
                    message: tapTooltip ?? message,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(message, style: tokens.bodyStyle),
                  ),
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: FanCadTokens.space2),
                FanCadIconButton(
                  icon: Icons.close,
                  size: 18,
                  iconSize: FanCadTokens.iconSmall,
                  tooltip: dismissTooltip,
                  onPressed: onDismiss,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

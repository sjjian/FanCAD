import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'shell_row.dart';

/// A panel-centered empty state. Optional action is a leftover accent row.
class ShellEmpty extends StatelessWidget {
  const ShellEmpty({
    super.key,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.messageStyle,
  });

  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FanCadTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: messageStyle ?? tokens.labelStyle,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: FanCadTokens.space3),
              Text(
                detail!,
                style: tokens.labelStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FanCadTokens.space2),
              ShellRow(
                onTap: onAction,
                height: FanCadTokens.rowHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space2,
                ),
                child: Text(
                  actionLabel!,
                  style: tokens.bodyStyle.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

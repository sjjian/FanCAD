import 'package:fancad_updater/fancad_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/l10n.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// The once-per-version prompt shown shortly after launch.
///
/// Closing the dialog with its close button, Escape or the barrier counts as
/// "later": the notifier already recorded the version, so it will not appear
/// again. The About page remains available.
Future<void> showUpdateAvailableDialog(
  BuildContext context, {
  required ReleaseInfo release,
  required String currentVersion,
  required VoidCallback onUpgrade,
  required VoidCallback onSkip,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => _UpdateAvailableDialog(
      release: release,
      currentVersion: currentVersion,
      onUpgrade: onUpgrade,
      onSkip: onSkip,
    ),
  );
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({
    required this.release,
    required this.currentVersion,
    required this.onUpgrade,
    required this.onSkip,
  });

  final ReleaseInfo release;
  final String currentVersion;
  final VoidCallback onUpgrade;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final notes = release.notes.trim();

    void close() => Navigator.of(context).pop();

    return Dialog(
      backgroundColor: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
        side: BorderSide(color: tokens.borderStrong),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FanCadTokens.space4,
            FanCadTokens.space3,
            FanCadTokens.space4,
            FanCadTokens.space3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.update_available_title(release.version),
                          style: tokens.dialogTitleStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.update_available_current(currentVersion),
                          style: tokens.labelStyle,
                        ),
                      ],
                    ),
                  ),
                  FanCadIconButton(
                    icon: Icons.close,
                    tooltip: l10n.close,
                    iconSize: FanCadTokens.iconSmall,
                    onPressed: close,
                  ),
                ],
              ),
              const SizedBox(height: FanCadTokens.space3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: notes.isEmpty
                      ? Text(l10n.about_no_notes, style: tokens.labelStyle)
                      : MarkdownBody(
                          data: notes,
                          selectable: true,
                          softLineBreak: true,
                          styleSheet: MarkdownStyleSheet(
                            p: tokens.bodyStyle,
                            h1: tokens.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            h2: tokens.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            h3: tokens.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            code: tokens.monoStyle.copyWith(
                              backgroundColor: tokens.surfaceRaised,
                            ),
                            listBullet: tokens.bodyStyle,
                            blockSpacing: FanCadTokens.space2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: FanCadTokens.space3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.text,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FanCadTokens.space3,
                      ),
                      side: BorderSide(color: tokens.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          FanCadTokens.radiusSmall,
                        ),
                      ),
                    ),
                    onPressed: () {
                      close();
                      onSkip();
                    },
                    child: Text(
                      l10n.update_available_skip,
                      style: tokens.bodyStyle,
                    ),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FanCadTokens.space3,
                      ),
                    ),
                    onPressed: () {
                      close();
                      onUpgrade();
                    },
                    child: Text(
                      l10n.update_available_upgrade,
                      style: tokens.bodyStyle.copyWith(
                        color: tokens.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/updates.dart';
import '../../services/updater.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// The About tab: product identity, version details and the update card.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final state = ref.watch(updateNotifierProvider);
    final build = ref.watch(buildInfoProvider);
    final notifier = ref.read(updateNotifierProvider.notifier);
    final release = state.release;
    final notes = release?.notes.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        _ProductHeader(tagline: l10n.about_tagline),
        const SizedBox(height: FanCadTokens.space4),
        SettingsSection(
          title: l10n.settings_tab_about,
          children: [
            SettingsLabeledRow(
              label: l10n.about_version,
              child: _Value(build.version),
            ),
          ],
        ),
        const SizedBox(height: FanCadTokens.space5),
        SettingsSection(
          title: l10n.about_updates,
          children: [
            SettingsToggle(
              key: const Key('settings-update-auto-check'),
              label: l10n.about_auto_check,
              value: state.autoCheck,
              onChanged: notifier.setAutoCheck,
              description: l10n.about_auto_check_hint,
              tooltip: l10n.about_auto_check_hint,
            ),
            _Status(state: state),
            if (state.phase == UpdatePhase.downloading) ...[
              const SizedBox(height: FanCadTokens.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
                child: LinearProgressIndicator(
                  value: state.progress?.fraction,
                  minHeight: 4,
                  backgroundColor: tokens.surfaceRaised,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(height: FanCadTokens.space1),
              Text(
                _progressText(l10n, state.progress),
                style: tokens.labelStyle.copyWith(color: tokens.textMuted),
              ),
            ],
            const SizedBox(height: FanCadTokens.space3),
            _Actions(state: state, onInstall: () => _install(context, ref)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: FanCadTokens.space3),
              _ReleaseNotes(notes: notes),
            ],
          ],
        ),
        const SizedBox(height: FanCadTokens.space5),
        SettingsSection(
          title: l10n.about_links,
          children: [
            _LinkRow(
              label: l10n.about_github,
              url: 'https://github.com/sjjian/FanCAD',
            ),
            _LinkRow(
              label: l10n.about_issues,
              url: 'https://github.com/sjjian/FanCAD/issues',
            ),
            _LinkRow(
              label: l10n.about_changelog,
              url: 'https://github.com/sjjian/FanCAD/releases',
            ),
          ],
        ),
        const SizedBox(height: FanCadTokens.space5),
        Center(
          child: Text(
            '© 2026 FanCAD · GPL-3.0',
            style: tokens.labelStyle.copyWith(color: tokens.textFaint),
          ),
        ),
      ],
    );
  }

  Future<void> _install(BuildContext context, WidgetRef ref) async {
    final state = ref.read(updateNotifierProvider);
    final version = state.release?.version;
    if (version == null) return;
    if (!await _confirmInstall(context, version)) return;
    final quit = await ref.read(updateNotifierProvider.notifier).install();
    if (quit) exit(0);
  }

  Future<bool> _confirmInstall(BuildContext context, String version) async {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                Text(
                  l10n.install_confirm_title(version),
                  style: tokens.dialogTitleStyle,
                ),
                const SizedBox(height: FanCadTokens.space2),
                Text(l10n.install_confirm_body, style: tokens.bodyStyle),
                const SizedBox(height: FanCadTokens.space3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SecondaryButton(
                      label: l10n.about_cancel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    _PrimaryButton(
                      label: l10n.install_confirm_action,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          child: Image.asset(
            'assets/icons/logo.png',
            width: 52,
            height: 52,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.precision_manufacturing_outlined,
              size: 48,
              color: tokens.accent,
            ),
          ),
        ),
        const SizedBox(width: FanCadTokens.space3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FanCAD',
              style: tokens.dialogTitleStyle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(tagline, style: tokens.labelStyle),
          ],
        ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.tokens.monoStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.state});

  final UpdateStateModel state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final version = state.release?.version ?? '';
    final percent = ((state.progress?.fraction ?? 0) * 100).round();
    final text = switch (state.phase) {
      UpdatePhase.idle => l10n.about_not_checked,
      UpdatePhase.checking => l10n.about_checking,
      UpdatePhase.upToDate => l10n.about_up_to_date,
      UpdatePhase.available => l10n.about_available(version),
      UpdatePhase.downloading => l10n.about_downloading(percent),
      UpdatePhase.ready => l10n.about_ready(version),
      UpdatePhase.installing => l10n.about_installing,
      UpdatePhase.failed => l10n.about_failed,
      UpdatePhase.unsupported => l10n.about_unsupported,
      UpdatePhase.unconfigured => l10n.about_unconfigured,
      UpdatePhase.reveal => l10n.about_reveal,
    };
    final isProblem =
        state.phase == UpdatePhase.failed ||
        state.phase == UpdatePhase.unconfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (state.phase == UpdatePhase.checking ||
                state.phase == UpdatePhase.installing) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              const SizedBox(width: FanCadTokens.space2),
            ],
            Expanded(
              child: Text(
                text,
                style: tokens.bodyStyle.copyWith(
                  color: isProblem ? tokens.danger : tokens.text,
                ),
              ),
            ),
          ],
        ),
        if (state.isSkipped && state.phase == UpdatePhase.available)
          Padding(
            padding: const EdgeInsets.only(top: FanCadTokens.space1),
            child: Text(
              l10n.about_skipped(version),
              style: tokens.labelStyle.copyWith(color: tokens.textMuted),
            ),
          ),
        if (state.error != null && state.error!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FanCadTokens.space1),
            child: Text(
              state.error!,
              style: tokens.labelStyle.copyWith(color: tokens.danger),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: FanCadTokens.space1),
          child: Text(
            l10n.about_source,
            style: tokens.labelStyle.copyWith(color: tokens.textFaint),
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state, required this.onInstall});

  final UpdateStateModel state;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(updateNotifierProvider.notifier);
    final actions = <Widget>[];
    switch (state.phase) {
      case UpdatePhase.idle:
      case UpdatePhase.reveal:
        actions.add(
          _PrimaryButton(
            label: l10n.about_check,
            onPressed: () => notifier.check(manual: true),
          ),
        );
      case UpdatePhase.upToDate:
        actions.add(
          _SecondaryButton(
            label: l10n.about_check,
            onPressed: () => notifier.check(manual: true),
          ),
        );
      case UpdatePhase.failed:
        actions.add(
          _PrimaryButton(
            label: l10n.about_retry,
            onPressed: () => notifier.check(manual: true),
          ),
        );
      case UpdatePhase.available:
        actions.add(
          _PrimaryButton(
            label: l10n.about_download,
            onPressed: notifier.download,
          ),
        );
        actions.add(
          state.isSkipped
              ? _SecondaryButton(
                  label: l10n.about_unskip,
                  onPressed: notifier.unskipVersion,
                )
              : _SecondaryButton(
                  label: l10n.about_skip,
                  onPressed: notifier.skipVersion,
                ),
        );
      case UpdatePhase.downloading:
        actions.add(
          _SecondaryButton(
            label: l10n.about_cancel,
            onPressed: notifier.cancelDownload,
          ),
        );
      case UpdatePhase.ready:
        actions.add(
          _PrimaryButton(label: l10n.about_install, onPressed: onInstall),
        );
      case UpdatePhase.checking:
      case UpdatePhase.installing:
      case UpdatePhase.unsupported:
      case UpdatePhase.unconfigured:
        break;
    }
    return Wrap(
      spacing: FanCadTokens.space2,
      runSpacing: FanCadTokens.space2,
      children: actions,
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      padding: const EdgeInsets.all(FanCadTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        border: Border.all(color: tokens.borderMuted),
      ),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: notes,
          selectable: true,
          softLineBreak: true,
          styleSheet: MarkdownStyleSheet(
            p: tokens.bodyStyle,
            h1: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w600),
            h2: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w600),
            h3: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w600),
            code: tokens.monoStyle.copyWith(
              backgroundColor: tokens.surfaceOverlay,
            ),
            listBullet: tokens.bodyStyle,
            blockSpacing: FanCadTokens.space2,
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: () => _openUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space1),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tokens.bodyStyle.copyWith(color: tokens.accent),
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: FanCadTokens.iconSmall,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', [url]);
      } else if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', url]);
      } else {
        await Process.start('xdg-open', [url]);
      }
    } catch (_) {
      // A desktop without an opener is not worth interrupting the page.
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: context.tokens.bodyStyle.copyWith(
          color: context.tokens.accentText,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.text,
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        side: BorderSide(color: tokens.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        ),
      ),
      onPressed: onPressed,
      child: Text(label, style: tokens.bodyStyle),
    );
  }
}

String _progressText(AppLocalizations l10n, DownloadProgress? progress) {
  if (progress == null) return '';
  final received = _bytes(progress.received);
  final total = progress.total;
  if (total == null || total <= 0) return received;
  return l10n.about_download_size(received, _bytes(total));
}

String _bytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}

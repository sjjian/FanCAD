import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';

/// Model / paper tabs under the drawing, matching the AutoCAD layout strip.
///
/// The document already stores layouts and `layout.set` already switches the
/// active block. Without this strip a paper tab is invisible: the user has a
/// sheet and viewports, but no way to open them from the shell.
class LayoutTabStrip extends StatelessWidget {
  const LayoutTabStrip({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = workspace.active;
    if (tab == null) return const SizedBox.shrink();
    final layouts = tab.document.layouts;
    if (layouts.isEmpty) return const SizedBox.shrink();
    final active = tab.document.activeLayoutName;

    return Container(
      height: FanCadTokens.tabBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
        itemCount: layouts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: FanCadTokens.space1),
        itemBuilder: (context, index) {
          if (index == layouts.length) {
            return _AddLayoutChip(
              onTap: () => workspace.run('layout.new'),
            );
          }
          final layout = layouts[index];
          final selected = layout.name == active;
          return _LayoutChip(
            layout: layout,
            selected: selected,
            onTap: () {
              if (selected) return;
              workspace.run('layout.set', args: {'name': layout.name});
            },
          );
        },
      ),
    );
  }
}

class _LayoutChip extends StatelessWidget {
  const _LayoutChip({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final Layout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: layout.isModelSpace
          ? 'Model space'
          : '${layout.paperWidth.toStringAsFixed(0)} × '
              '${layout.paperHeight.toStringAsFixed(0)} mm',
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            layout.name,
            style: tokens.labelStyle.copyWith(
              color: selected ? tokens.text : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLayoutChip extends StatelessWidget {
  const _AddLayoutChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: 'New paper layout',
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          child: Text(
            '+',
            style: tokens.labelStyle.copyWith(color: tokens.textMuted),
          ),
        ),
      ),
    );
  }
}

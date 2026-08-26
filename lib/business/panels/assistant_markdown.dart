import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/tokens.dart';

/// Renders an assistant reply as Markdown using the FanCAD type scale.
///
/// Tool rows stay monospaced receipts. Only the model's own words go through
/// here, so a heading or a fenced block does not have to fight the command
/// log. Selectable so a leftover copy does not depend on a hidden gesture.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MarkdownBody(
      data: text,
      selectable: true,
      softLineBreak: true,
      styleSheet: _sheet(tokens),
      imageBuilder: (_, _, _) => const SizedBox.shrink(),
      onTapLink: (_, _, _) {},
    );
  }

  static MarkdownStyleSheet _sheet(FanCadTokens tokens) {
    final body = tokens.bodyStyle.copyWith(fontSize: 13, height: 1.55);
    final muted = tokens.labelStyle.copyWith(height: 1.45);
    final mono = tokens.monoStyle.copyWith(fontSize: 12, height: 1.45);
    return MarkdownStyleSheet(
      p: body,
      pPadding: const EdgeInsets.only(bottom: FanCadTokens.space2),
      blockSpacing: FanCadTokens.space3,
      h1: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
      h1Padding: const EdgeInsets.only(
        top: FanCadTokens.space2,
        bottom: FanCadTokens.space2,
      ),
      h2: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
      h2Padding: const EdgeInsets.only(
        top: FanCadTokens.space2,
        bottom: FanCadTokens.space1,
      ),
      h3: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
      h3Padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
      em: body.copyWith(fontStyle: FontStyle.italic),
      strong: body.copyWith(fontWeight: FontWeight.w600),
      a: body.copyWith(color: tokens.accent),
      code: mono.copyWith(
        backgroundColor: tokens.surfaceRaised,
        color: tokens.text,
      ),
      codeblockPadding: const EdgeInsets.all(FanCadTokens.space3),
      codeblockDecoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        border: Border.all(color: tokens.border),
      ),
      blockquote: muted,
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: tokens.accent, width: 2)),
      ),
      blockquotePadding: const EdgeInsets.only(left: FanCadTokens.space3),
      listBullet: body,
      listIndent: FanCadTokens.space4,
      listBulletPadding: const EdgeInsets.only(right: FanCadTokens.space2),
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      tableBody: body,
      tableBorder: TableBorder.all(color: tokens.border, width: 0.5),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: FanCadTokens.space2,
        vertical: FanCadTokens.space1,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
    );
  }
}

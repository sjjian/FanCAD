import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../services/composer_pin.dart';
import '../theme/tokens.dart';
import '../widgets/object_pin_chip.dart';

/// Renders an assistant reply as Markdown using the FanCAD type scale.
///
/// Tool rows stay monospaced receipts. Only the model's own words go through
/// here, so a heading or a fenced block does not have to fight the command
/// log. Selectable so a leftover copy does not depend on a hidden gesture.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({
    super.key,
    required this.text,
    this.onEntityId,
    this.onHoverEntityId,
    this.onPin,
    this.onHoverPin,
    this.resolvePin,
  });

  final String text;
  final ValueChanged<int>? onEntityId;
  final ValueChanged<int?>? onHoverEntityId;
  final ValueChanged<ComposerPin>? onPin;
  final ValueChanged<ComposerPin?>? onHoverPin;
  final ComposerPin Function(ComposerPin pin)? resolvePin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MarkdownBody(
      data: _linkEntityIds(text),
      selectable: true,
      softLineBreak: true,
      styleSheet: _sheet(tokens),
      sizedImageBuilder: (_) => const SizedBox.shrink(),
      inlineSyntaxes: [_ComposerPinSyntax()],
      builders: {
        'a': _EntityLinkBuilder(onTap: onEntityId, onHover: onHoverEntityId),
        'composerpin': _ComposerPinBuilder(
          onTap: onPin,
          onHover: onHoverPin,
          resolve: resolvePin,
        ),
      },
      onTapLink: (text, href, title) {
        final id = _entityIdFromHref(href);
        if (id != null) onEntityId?.call(id);
      },
    );
  }

  static String _linkEntityIds(String text) {
    return text.replaceAllMapped(
      RegExp(r'#(\d+)'),
      (match) => '[${match[0]}](#entity-${match[1]})',
    );
  }

  static int? _entityIdFromHref(String? href) {
    if (href == null || !href.startsWith('#entity-')) return null;
    return int.tryParse(href.substring('#entity-'.length));
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

class _ComposerPinSyntax extends md.InlineSyntax {
  _ComposerPinSyntax()
    : super(
        r'@objects\[tab=[^\s\]]+\s+ids=\d+(?:\s*,\s*\d+)*\]'
        r'|@drawing\[tab=[^\s\]]+\]',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('composerpin', match[0]!));
    return true;
  }
}

class _ComposerPinBuilder extends MarkdownElementBuilder {
  _ComposerPinBuilder({this.onTap, this.onHover, this.resolve});

  final ValueChanged<ComposerPin>? onTap;
  final ValueChanged<ComposerPin?>? onHover;
  final ComposerPin Function(ComposerPin pin)? resolve;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final pin = parseComposerPin(element.textContent);
    if (pin == null) return Text(element.textContent, style: preferredStyle);
    return ObjectPinChip(
      pin: resolve?.call(pin) ?? pin,
      onFlash: onTap == null ? null : () => onTap!(pin),
      onHover: onHover == null
          ? null
          : (hovered) => onHover!(hovered ? pin : null),
    );
  }
}

class _EntityLinkBuilder extends MarkdownElementBuilder {
  _EntityLinkBuilder({this.onTap, this.onHover});

  final ValueChanged<int>? onTap;
  final ValueChanged<int?>? onHover;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final id = AssistantMarkdown._entityIdFromHref(element.attributes['href']);
    final label = element.textContent;
    final text = Text(label, style: preferredStyle);
    if (id == null) return text;
    return MouseRegion(
      key: Key('assistant-entity-$id'),
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover?.call(id),
      onExit: (_) => onHover?.call(null),
      child: GestureDetector(onTap: () => onTap?.call(id), child: text),
    );
  }
}

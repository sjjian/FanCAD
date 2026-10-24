/// Evaluates the small `when` clause on a menu item or keybinding.
///
/// The clause is a conjunction of `hasSelection` and `commandIdle`, each of
/// which may be negated with `!`. An empty clause matches. An unknown word
/// does not, so a typo hides the item instead of showing it everywhere.
bool contributionWhen(
  String? expression, {
  required bool hasSelection,
  required bool commandIdle,
}) {
  final raw = expression?.trim() ?? '';
  if (raw.isEmpty) return true;
  for (final part in raw.split('&&')) {
    final token = part.trim();
    if (token.isEmpty) continue;
    final negated = token.startsWith('!');
    final name = (negated ? token.substring(1) : token).trim();
    final value = switch (name) {
      'hasSelection' => hasSelection,
      'commandIdle' => commandIdle,
      _ => null,
    };
    if (value == null) return false;
    if (negated ? value : !value) return false;
  }
  return true;
}

/// Programs tried for one extension or exec snippet, in order.
///
/// QuickJS evaluates a file as a plain script, where a top-level `await` is
/// `SyntaxError: expecting ';'` and a top-level `return` is
/// `return not in a function`. The file is an async function body instead, so
/// the header comment, `await fancad.commands.execute`, and `return` all run.
/// An expression is tried first so `1 + 1` and a bare `await` still yield a
/// value; a statement script falls through to the body. A thrown error is
/// caught in that same function and returned as [extensionFailure], so the
/// worker does not see an unhandled rejection.
List<String> extensionPrograms(String source) => [
  _extensionProgram('return{__fancadStatus:"ok",value:(\n$source\n)};'),
  _extensionProgram('$source\nreturn{__fancadStatus:"ok",value:void 0};'),
];

String _extensionProgram(String body) =>
    '(async()=>{try{\n'
    '$body\n'
    '}catch(e){const message=(e&&e.message?String(e.message)+"\\n":"")+'
    '(e&&e.stack?String(e.stack):String(e));'
    'return{__fancadStatus:"failed",message:message};}})()';

/// The message from a program that caught a JavaScript exception.
String? extensionFailure(Object? envelope) {
  if (envelope is! Map || envelope['__fancadStatus'] != 'failed') return null;
  final message = envelope['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  return 'the extension failed';
}

/// The value a program returned. An envelope that is not ours is left as-is.
Object? extensionValue(Object? envelope) {
  if (envelope is Map && envelope['__fancadStatus'] == 'ok') {
    return envelope['value'];
  }
  return envelope;
}

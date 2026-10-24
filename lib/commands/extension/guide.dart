/// How to write a saved extension. Returned by `extensions.doc`.
const extensionGuide = r'''
A saved extension is one JavaScript file. Try the snippet with the exec tool first. Save it with extensions.write args={name, content}. Run the saved file as extension.<name>.

The file is an async function body. The opening comment is not code. Top-level await and return are valid. fancad.args is the parameter object declared below. While exec is trying the snippet, fancad.args is {}.

/**
 * description: Draws a circle.
 * usage: Pick a center.
 * param center: point Center
 * param radius: number = 10 Radius
 */
const drawn = await fancad.commands.execute("draw.circle", {
  center: fancad.args.center,
  radius: fancad.args.radius,
});
return drawn;

A param line is: param <name>: <type> [= default] [description]
name is an identifier. type is text, number, integer, boolean, point, distance, angle, entity, selection, layer, block, choice, json, or points. A default makes the parameter optional. Quote a text, layer, block, or choice default that has spaces: = "Hello world". point, selection, json, and points take no default. angle is degrees. A param line that cannot be read stops the extension from running until it is fixed.

Call a command with await fancad.commands.execute(path, args). path and args match fancad action=run. Read them with fancad help and schema before writing the call. Do not call help, schema, exec, or extension.<name> from the file. Destructive commands fail inside a script: edit.erase, edit.apply with replace or an erase operation, saving or closing a file, undo and redo, and extensions.write, delete, or run. Return what should be removed and let the caller erase it. Batch drawing changes with commands.execute("edit.apply", ...) so they undo together; its arguments are on fancad schema path=edit.apply.

fancad.document.summary(), fancad.document.query(filter), fancad.document.entity(id), and fancad.selection.get() read the drawing. fancad.document.edit(label, operations) is edit.apply. Return the value the caller should see.
''';

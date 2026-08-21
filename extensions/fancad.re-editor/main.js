// FanCAD Re-Editor
//
// A thin command surface over the host's plugin file commands. The actual
// editor widget lives in the Flutter shell (PluginEditorPanel); this plugin
// exists so the AI authoring loop and a person use the same verbs to open it.

const { commands, window: win } = fancad;

commands.register('reEditor.open', async (args) => {
  const id = String(args.id ?? '');
  const path = String(args.path ?? 'main.js');
  if (!id) throw new Error('an extension id is required');

  const result = await commands.execute('plugins.edit', { id, path });
  if (result.status !== 'ok') {
    await win.showError(result.message ?? `Could not open ${id}/${path}`);
  }
  return result;
});

commands.register('reEditor.list', async (args) => {
  const id = String(args.id ?? '');
  if (!id) throw new Error('an extension id is required');
  return commands.execute('plugins.read', { id, path: 'fancad.plugin.json' });
});

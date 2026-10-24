/// Drawing CLI. Saved extensions are [extensionsToolName], not a path on this tool.
const fancadToolName = 'fancad';

/// Extension CLI. Management, creation, and running one saved extension share it.
const extensionsToolName = 'extensions';

/// Wire shape so models do not nest `path` inside `args`.
const fancadCallExample =
    '{"action":"run","path":"draw.circle","args":{"center":[0,0],"radius":10}}';

/// Instructions that teach progressive discovery instead of listing 150 tools.
const fancadToolDescription =
    'Draws, edits, and queries the open drawing. One tool for every drawing '
    'command. To see the drawing, run print.export with format png and no '
    'path; the picture comes back. Frame it with corner1 and corner2, or '
    'scope selection. Do not export extents or the whole drawing. '
    'Saved extensions are the extensions tool. '
    'Do not guess parameters. help with no path lists groups; help path=draw '
    'lists that group; help path=draw.line returns parameters. schema '
    'path=draw.line returns JSON Schema. run path=draw.line args={...} '
    'executes. path is a sibling of action, never inside args. '
    'Example: $fancadCallExample. '
    'For a drawing that is open but not showing, call file.list and pass tab.';

/// Same discovery shape as [fancadToolDescription], for the extension collection.
const extensionsToolDescription =
    'Lists, reads, writes, deletes, and runs saved extensions. Unsaved '
    'JavaScript is exec, not this tool. Run extensions.doc before writing one. '
    'Same help, schema, then run as fancad. path is a sibling of action, '
    'never inside args. extensions.list takes no args. read and delete take '
    '{name}. write takes {name, content}; put description, usage, and params '
    'in the opening comment. extension.<name> runs one saved extension. '
    'Example: {"action":"run","path":"extensions.list"}.';

/// A saved-extension command offered by [extensionsToolName], not by [fancadToolName].
///
/// `extensions.run` is an unsaved snippet and stays off both CLIs.
bool isExtensionCliCommand(String id) =>
    id == 'extensions.list' ||
    id == 'extensions.read' ||
    id == 'extensions.write' ||
    id == 'extensions.delete' ||
    id == 'extensions.doc' ||
    id.startsWith('extension.');

const fancadToolParameters = <String, Object?>{
  'type': 'object',
  'properties': {
    'action': {
      'type': 'string',
      'enum': ['list', 'help', 'schema', 'run'],
      'description':
          'help lists groups or one command. schema returns JSON Schema. '
          'run executes path. list is the short form of help.',
    },
    'path': {
      'type': 'string',
      'description':
          'Group or command id, such as draw or draw.line. Omit on help to '
          'list groups.',
    },
    'args': {
      'type': 'object',
      'description': 'Parameters from help or schema. Do not put path here.',
    },
    'tab': {
      'type': 'string',
      'description':
          'Open drawing to run against. Call file.list and pass that id. '
          'Omit for the active drawing. Does not switch the visible tab; '
          'file.activate does.',
    },
  },
  'required': ['action'],
};

/// Wire shape shared by the assistant [LlmTool] and MCP `tools/list`.
Map<String, Object?> fancadToolDefinition() => {
  'name': fancadToolName,
  'description': fancadToolDescription,
  'parameters': fancadToolParameters,
};

/// Same argument object as [fancadToolParameters]. The description differs.
const extensionsToolParameters = fancadToolParameters;

/// MCP `inputSchema` is the parameters object plus a name/description.
Map<String, Object?> fancadMcpTool() => {
  'name': fancadToolName,
  'description': fancadToolDescription,
  'inputSchema': fancadToolParameters,
};

/// MCP `inputSchema` for [extensionsToolName].
Map<String, Object?> extensionsMcpTool() => {
  'name': extensionsToolName,
  'description': extensionsToolDescription,
  'inputSchema': extensionsToolParameters,
};

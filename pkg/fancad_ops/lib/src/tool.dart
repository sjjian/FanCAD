/// The only tool advertised to a model or an MCP client.
const fancadToolName = 'fancad';

/// Instructions that teach progressive discovery instead of listing 150 tools.
const fancadToolDescription =
    'FanCAD CLI. One entry for every drawing command and host operation. '
    'Do not guess parameters. '
    '1. Call with action=help and no path to list groups (draw, edit, query, …). '
    '2. action=help path=draw to list commands in a group. '
    '3. action=help path=draw.line for parameters, aliases and risk. '
    '4. action=schema path=draw.line for the JSON Schema. '
    '5. action=run path=draw.line with args from that help. '
    'To operate a background drawing, call file.list then pass tab with that id. '
    'Skills load with action=run path=skill.read args={name: inspect-drawing}.';

const fancadToolParameters = <String, Object?>{
  'type': 'object',
  'properties': {
    'action': {
      'type': 'string',
      'enum': ['list', 'help', 'schema', 'run'],
      'description':
          'list or help discover groups and commands. schema returns JSON '
          'Schema. run executes a command id.',
    },
    'path': {
      'type': 'string',
      'description':
          'Group or dotted command id, for example draw or draw.line. '
          'Omit for the top-level group list.',
    },
    'args': {
      'type': 'object',
      'description': 'Arguments for action=run, taken from help/schema.',
    },
    'tab': {
      'type': 'string',
      'description':
          'Open drawing to run against. Call file.list first and pass the '
          'drawing id. A unique file path or title also works. Omit to use the '
          'active drawing. Does not switch the visible tab; use file.activate '
          'for that.',
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

/// MCP `inputSchema` is the parameters object plus a name/description.
Map<String, Object?> fancadMcpTool() => {
  'name': fancadToolName,
  'description': fancadToolDescription,
  'inputSchema': fancadToolParameters,
};

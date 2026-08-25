/// The FanCAD assistant: provider abstraction, agent loop, document context
/// and the approval gate that stands between a tool call and the drawing.
library;

export 'src/agent.dart';
export 'src/approval.dart';
export 'src/authoring.dart';
export 'src/context.dart';
export 'src/conversation.dart';
export 'src/mock_provider.dart';
export 'src/openai_provider.dart';
export 'src/provider.dart';
export 'src/skills/bundled.dart';
export 'src/skills/host_tools.dart';
export 'src/skills/skill.dart';
export 'src/tools.dart';

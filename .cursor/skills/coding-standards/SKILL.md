---
name: coding-standards
description: 基于当前仓库现状约束实现阶段的编码规范，覆盖 Dart/Flutter 分层与 pkg 边界。Use when adding or refactoring code in lib or pkg, or when the user mentions 编码规范、代码风格、项目约定、分层、screen、services、storage。
---

# 编码规范

只保留项目特有的实现约束，不解释框架知识。

## 必须

- 先读当前模块已有实现，再写代码；优先局部一致，不顺手做无关重构。
- 新代码跟着所在层的目录走；Dart 文件用 `snake_case`。
- 应用按 `screen` → `services` → (`models` + storage views) → `SettingsStore` → `pkg/*` 分层。依赖只朝下；`pkg` 不得 `import package:fancad/...`。`commands` / `l10n` / `ai` 是产品侧包，不是夹在 screen 和 services 之间的层。
- `models` 只放应用层形状和 JSON。运行时 store：`workspace.dart`（`WorkspaceModel`）、`assistant.dart`（`AssistantModel`）、`command_line.dart`（`CommandLineModel`）、`layout.dart`（`LayoutModel`：侧栏视图和开关、助手栏开关、侧栏宽、助手栏宽、命令行高）、`sidebar.dart`（只留 `SidebarLayout` 的宽高界限）、`plugin.dart`（`PluginModel`、`PluginEditorModel`）。`CommandLineModel` 含展开和未持久化的 `paletteOpen`。面板高度在 `LayoutModel`。配置形状在 `models/settings.dart`：`AppearanceModel`（主题、语言）、`McpModel`（`McpBindModel bind` 和 endpoint token）、`DrawingModel`（最近文件和草图开关，只给磁盘，不进 Riverpod）、`AssistantProfileModel`（一份连接）、`AssistantAccountsModel`（账户列表、当前账户、key 环境变量、自动批准）。扩展编辑是 `PluginEditorModel`、扩展宿主是 `PluginModel`，全局独立，不挂 `WorkspaceModel`。`workspace` 存 sessions/notices/approval/runningCommand/snap chrome/lastCreated；`assistant` 是对话、pin、busy、transcriptEpoch。停靠栏开关和宽度在 `LayoutModel`。连接配置在 `AssistantAccountsModel`，由 `services/settings.dart` 的 `AssistantAccountsNotifier` 写入。外观、MCP、助手账户这三个 Notifier 都在 `services/settings.dart`。本机 MCP 监听也在 `McpNotifier` 上，不要再造 OpsHost。不碰磁盘。带字段的值对象用 Freezed（`@freezed`），类名统一 `*Model` 后缀，不要手写 `copyWith` / `==`；闭合词表用 Dart enum。打开的图纸是 `DocumentSession`，经 Workspace 的 `sessionIds` / `session(id)` 访问，不平行造图纸 DTO。CAD 几何留在 `pkg/fancad_core`。`WorkspaceSettings` / `SidebarSettings` / `AppearanceSettings` 等是 storage view，不得出 services；screen 只看 model。审批 Completer 留在 services 的 `PendingApproval`；助手的 approval/question Completer 留在 `AssistantNotifier`。画布高亮：`approval.highlightIds` 只跟审批走；session 的 `heldIds` / `flashIds` / `hoverIds` 各自写入，不要再把 `approval` 当高亮袋。
- `services` 的 Riverpod 用 `@riverpod` / `@Riverpod` 注解，由 `build_runner` 生成 `*.g.dart`。不要手写 `Provider()` / `StateNotifierProvider()`。Riverpod 负责注入。有 store 的 service 都是 Notifier，`state` 即对应 `*Model`：`WorkspaceNotifier`、`AssistantNotifier`、`CommandLineNotifier`、`PluginEditorNotifier`、`PluginNotifier`、`LayoutNotifier`、`AppearanceNotifier`、`McpNotifier`、`AssistantAccountsNotifier`、family `DocumentTabNotifier`。外观、MCP 和助手账户在 `services/settings.dart`。不要再写成 `ChangeNotifier`，也不要在 `providers.dart` 为这些 store 叠一层切片 provider。方法 / hosts / `run` 走 `*.notifier`。`CoordinateParser`、`ShxFontCatalog`、`createFanCadHostCall`、Completer、leaf provider（`settings` / `importer` / `commandRegistry` / `pluginTransport`）不配 store。`DocumentTabNotifier.state` 只放 prompt；`session` / `viewport` / `tools` 留字段。`isStartPage`、`diagnostics`、`showGrid`、tab 条上的 `title` / `isDirty` 只写 `WorkspaceSessionModel`，经 `bindStore` 读。平移/工具帧只 tick tab 的 `Listenable`，禁止把相机写进 Riverpod `state`。
- `screen` 按 `assistant`、`widgets`、`settings`、`workspace`、`command_line`、`plugin` 分目录，`app.dart` 留在根上。主题、token、标题栏、活动栏和共用控件都在 `widgets`，类名用 `FanCad` 前缀。侧栏和外观的 store 仍在 `services`，不单开 screen 目录。不定义可共享 DTO，只通过 `WorkspaceNotifier.run` / 已有 service provider 做事，不 import `storage`，不 `watch` `appSettingsProvider`。用 `ref.watch(*NotifierProvider.select(...))` 控制刷新：tab 条订 `tabStrip`，通知订 `notices`，画布订 `highlightIds` + `assistantBusy`，HUD 订 snap / `runningCommand` 和 command-line 切片，布局订 `LayoutModel`，助手订 transcriptEpoch / busy / pins，外观订 theme / language，扩展订 `PluginModel.epoch`。不要整树 `watch` 这些 Notifier。画布平移/光标继续 `ListenableBuilder`（tab / viewport），HUD 的 listen 不要包住 canvas `child`。图层/特性/布局订 `active` id，内容听 active tab。从 services 读到的形状必须来自 `models`。
- 不要手改 `*.freezed.dart`、`*.g.dart`，除非任务明确要求。
- `storage` 的 `SettingsStore` 是原始 KV；各业务用自己的 view 组合同一份 `settings.json`。文件与 `services` 模块对齐：`settings.dart`（含外观和 MCP）、`assistant.dart`、`layout.dart`、`workspace.dart`、`plugin.dart`，外加组装用的 `app_settings.dart`。对外是 `AppearanceStore`、`McpStore`、`AssistantStore`、`LayoutStore`、`WorkspaceStore` 的 `load` / `save`，参数和返回值是 model。`LayoutStore` 读写的 `LayoutModel` 是状态，由 `LayoutNotifier` 持有，不算配置形状。`PluginStore` 仍是扩展自己的 key/value。`SettingsStore` / `SettingsKeys` 不出 storage。
- `services` 依赖这些接口和 `models`，不直接读写 `SettingsStore` / `SettingsKeys`。只有 composition root（`providers.dart`、`main.dart`）打开 store。view 只在 services 内读写；对外字段和 provider state 必须是 `models`。
- `services` 不建 Widget。
- `storage` 只做读写、键名和 view，不做命令编排。
- CAD 动词仍是 `CommandDescriptor`，放在 `lib/commands/`，由 `Workspace.run` / `runHeadless` 调用。不要把 `draw.line` / `edit.erase` 改成 `*Services`。
- CAD 平台能力进 `fancad` CLI/MCP（`CommandDescriptor` 或 host operation，经 `OperationCatalog` 的 help/run）。没有 in-app AI chat 仍成立的能力走这条。AI chat 能力（必须有对话、composer、transcript 卡片）在 `fancad_ai` 注册独立 `LlmTool`，禁止放进 `OperationCatalog`，MCP `tools/list` 也不暴露。
- DWG 导入只按文件字段解释（`entmode`、`ownerhandle`、`entities[]`、几何、`DIMENSION.block`）。文件里已经写清的对象不要用距离、层名黑名单或「孤立」去改归属或丢掉。

## 不要

- 不要把 FanCAD 命令、助手文案、演示图沉进 `pkg/`。
- 不要把 AI chat 原语（ask、对话卡片）注册成 `fancad` path / host operation。
- 不要把别的模块的写法硬搬到当前目录。
- 不要在页面层直接做持久化或打开文档。
- 不要手改 generated 的 l10n、`*.freezed.dart`、`*.g.dart` 文件，除非任务明确要求。
- 在对某个文件进行变更时，禁止未经注明将一个文件内的内容拆分到另一个新文件。
- 不要删除已经加过的注释，它们都有非常重要的作用。

## 收尾检查

- 是否保持了当前目录既有职责边界。
- 是否把产品编排写进了 `pkg/`。
- 是否把 chat 能力塞进了 CLI/MCP。
- 是否误改 generated 文件。

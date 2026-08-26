---
name: coding-standards
description: 基于当前仓库现状约束实现阶段的编码规范，覆盖 Dart/Flutter 分层与 pkg 边界。Use when adding or refactoring code in lib or pkg, or when the user mentions 编码规范、代码风格、项目约定、分层、business、services、storage。
---

# 编码规范

只保留项目特有的实现约束，不解释框架知识。

## 必须

- 先读当前模块已有实现，再写代码；优先局部一致，不顺手做无关重构。
- 新代码跟着所在层的目录走；Dart 文件用 `snake_case`。
- 应用按 `business` → `services` → `storage` → `pkg/*` 分层。依赖只朝下；`pkg` 不得 `import package:fancad/...`。
- `business` 只通过 `Workspace.run` / 已有 service provider 做事，不读写 `settings.json`、不直接 `FcbCache`。
- `services` 可以调 `storage` 和 `pkg`，不建 Widget。
- `storage` 只做读写与键名，不做命令编排。
- CAD 动词仍是 `CommandDescriptor`，放在 `lib/business/commands/`，由 `Workspace.run` / `runHeadless` 调用。不要把 `draw.line` / `edit.erase` 改成 `*Services`。

## 不要

- 不要把 FanCAD 命令、助手文案、演示图沉进 `pkg/`。
- 不要把别的模块的写法硬搬到当前目录。
- 不要在页面层直接做持久化或打开文档。
- 不要手改 generated 的 l10n 文件，除非任务明确要求。
- 在对某个文件进行变更时，禁止未经注明将一个文件内的内容拆分到另一个新文件。
- 不要删除已经加过的注释，它们都有非常重要的作用。

## 收尾检查

- 是否保持了当前目录既有职责边界。
- 是否把产品编排写进了 `pkg/`。
- 是否误改 generated 文件。

import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'leftover composer copy keeps follow-up and context off the working row',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(en.ask_follow_up, 'Add a follow-up');
      expect(zh.ask_follow_up, '继续提问');
      expect(
        en.ask_assistant_unavailable,
        'Model unavailable. Configure it in Settings.',
      );
      expect(zh.ask_assistant_unavailable, '模型不可用，请先在设置中配置');
      expect(en.ask_assistant_unavailable, isNot(en.ask_assistant));
      expect(en.context_used('12.4k', '128k'), '12.4k / 128k');
      expect(
        en.context_used('12.4k', '128k'),
        isNot(contains('prompt_tokens')),
      );
      expect(en.assistant_profiles, 'Models');
      expect(zh.add_assistant_profile, '添加模型');
      expect(en.settings_tab_models, 'Models');
      expect(zh.settings_current_model, '当前模型');
      expect(en.new_chat, 'New chat');
      expect(zh.new_chat, '新会话');
      expect(zh.chat_history, '会话');
      expect(en.view_history_hint, isNot(en.view_commands_hint));
      expect(zh.view_history_hint, isNot(zh.view_commands_hint));
      expect(en.view_layouts_hint, isNot(en.view_layers_hint));
      expect(zh.view_layouts_hint, isNot(zh.view_layers_hint));
      expect(en.layouts, 'Layouts');
      expect(zh.layouts, '布局');
      expect(
        en.assistant_canvas_locked,
        'The assistant is working. The drawing cannot be edited.',
      );
      expect(zh.assistant_canvas_locked, '助手正在操作，图纸暂不可编辑。');
    },
  );

  test('leftover thinking copy is a card title, not working text', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.thinking, 'Thinking');
    expect(zh.thinking, '思考');
    expect(en.thinking, isNot(en.working));
    expect(zh.thinking, isNot(zh.working));
  });

  test('leftover approval copy asks only about deletes', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.ask_before_edits, contains('deletes'));
    expect(en.ask_before_edits, isNot(contains('edits the drawing')));
    expect(zh.ask_before_edits, contains('删除'));
    expect(zh.ask_before_edits, isNot(contains('修改图纸')));
  });

  test('a leftover approval title still localizes without dumping args', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.allow_one_change('Ellipse'), 'Allow Ellipse?');
    expect(en.allow_n_changes(8), 'Allow 8 changes?');
    expect(en.affects_n_objects(2), 'Affects 2 object(s).');
    expect(zh.allow_one_change('Ellipse'), '允许Ellipse？');
    expect(zh.allow_n_changes(8), '允许 8 处更改？');
    expect(zh.affects_n_objects(2), '影响 2 个对象。');
    expect(en.allow_one_change('Ellipse'), isNot(contains('center')));
  });

  test('a leftover command id keeps the English registry title', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(l10n.commandTitle('draw.line', 'Line'), '直线');
    expect(l10n.commandTitle('workbench.preferences', 'Settings...'), '设置...');
    expect(l10n.commandTitle('query.selection', 'Query Selection'), '查询选择集');
    expect(l10n.commandTitle('query.viewport', 'Query Viewport'), '查询视口');
    expect(
      l10n.commandTitle('plugin.unknown', 'My Plugin Command'),
      'My Plugin Command',
    );
  });

  test(
    'a leftover command description and step prompt follow the UI language',
    () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        zh.commandDescription(
          'draw.line',
          'Draws one or more connected straight line segments.',
        ),
        contains('直线'),
      );
      expect(
        en.commandDescription(
          'draw.line',
          'Draws one or more connected straight line segments.',
        ),
        contains('straight line'),
      );
      expect(
        zh.commandDescription('plugin.unknown', 'My plugin does a thing.'),
        'My plugin does a thing.',
      );
      expect(
        zh.command_step('LINE', zh.prompt_specify_first_point),
        'LINE  指定第一点:',
      );
      expect(
        en.command_step('LINE', en.prompt_specify_first_point),
        'LINE  Specify first point:',
      );
      expect(zh.prompt_idle_select, contains('选择'));
      expect(zh.prompt_select_object_to_trim, contains('修剪'));
      expect(zh.prompt_select_object_to_extend, contains('延伸'));
    },
  );

  test('every built-in command title and description has a locale string', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    for (final descriptor in [
      ...DrawCommands.all(),
      ...EditCommands.all(),
      ...ViewCommands.all(),
      ...QueryCommands.all(),
      ...ProCommands.all(),
    ]) {
      expect(
        zh.commandTitle(descriptor.id, 'FALLBACK'),
        isNot('FALLBACK'),
        reason: '${descriptor.id} needs a command title key',
      );
      expect(
        zh.commandDescription(descriptor.id, 'FALLBACK'),
        isNot('FALLBACK'),
        reason: '${descriptor.id} needs a command_*_desc key',
      );
    }
  });

  test('a leftover command category keeps the registry name', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(l10n.commandCategory('Draw'), '绘图');
    expect(l10n.commandCategory('Custom'), 'Custom');
  });

  testWidgets('missing localizations leftover falls back to English', (
    tester,
  ) async {
    late AppLocalizations resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = context.l10n;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved.layers, 'Layers');
    expect(resolved.localeName, 'en');
  });
}

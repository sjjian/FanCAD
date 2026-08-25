import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty leftover language is English, the default', () {
    expect(FanCadLanguage.parse(null), FanCadLanguage.english);
    expect(FanCadLanguage.parse(''), FanCadLanguage.english);
    expect(FanCadLanguage.parse('   '), FanCadLanguage.english);
  });

  test('regional and mixed-case leftovers still resolve', () {
    expect(FanCadLanguage.parse('en-US'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('EN'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('zh'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('zh_CN'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('zh-Hans'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('ZH-TW'), FanCadLanguage.chinese);
  });

  test('an unsupported leftover language does not blank the shell', () {
    expect(FanCadLanguage.parse('fr'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('de-DE'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('??'), FanCadLanguage.english);
  });

  test('leftover composer copy keeps follow-up and context off the working row',
      () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.ask_follow_up, 'Add a follow-up');
    expect(zh.ask_follow_up, '继续提问');
    expect(en.context_used('12.4k', '128k'), '12.4k / 128k');
    expect(en.context_used('12.4k', '128k'), isNot(contains('prompt_tokens')));
    expect(en.assistant_profiles, 'Configurations');
    expect(zh.add_assistant_profile, '添加配置');
    expect(en.new_chat, 'New chat');
    expect(zh.new_chat, '新会话');
    expect(zh.chat_history, '会话');
  });

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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get theme_dark => '深色';

  @override
  String get theme_light => '浅色';

  @override
  String get theme_system => '跟随系统';

  @override
  String get appearance_dark_tooltip => '外观 — 深色。可切换浅色、深色或跟随系统';

  @override
  String get appearance_light_tooltip => '外观 — 浅色。可切换浅色、深色或跟随系统';

  @override
  String get settings => '设置';

  @override
  String get settings_tooltip => '设置。主题、语言和助手';

  @override
  String get settings_tab_general => '常规';

  @override
  String get settings_tab_assistant => '助手';

  @override
  String get settings_tab_models => '模型';

  @override
  String get settings_tab_mcp => 'MCP';

  @override
  String get settings_appearance => '外观';

  @override
  String get settings_mcp => 'MCP';

  @override
  String get settings_mcp_enable => '网络接入';

  @override
  String get settings_mcp_on => '用下面的地址接入 Cursor 或 Claude Desktop';

  @override
  String get settings_mcp_off => '外部 MCP 客户端无法接入';

  @override
  String get settings_mcp_url => '地址';

  @override
  String get settings_mcp_local => '仅本地';

  @override
  String get settings_mcp_local_on => '只有这台电脑可以连接';

  @override
  String get settings_mcp_local_off => '其他机器可以连接，白名单可选';

  @override
  String get settings_mcp_port => '端口';

  @override
  String get settings_mcp_allowlist => 'IP 白名单';

  @override
  String get settings_mcp_allowlist_hint => '可选，逗号分隔';

  @override
  String get settings_current_model => '当前模型';

  @override
  String get settings_connection => '连接';

  @override
  String get settings_api_key => 'API 密钥';

  @override
  String get settings_api_key_env => 'API 密钥环境变量';

  @override
  String get open_settings => '打开设置';

  @override
  String get new_drawing => '新建图纸';

  @override
  String get new_tab => '新建标签页';

  @override
  String get start_tab => '开始';

  @override
  String get open => '打开';

  @override
  String get open_ellipsis => '打开…';

  @override
  String get save => '保存';

  @override
  String get save_as => '另存为…';

  @override
  String get save_unsaved_changes => '保存未保存的更改';

  @override
  String get save_this_drawing => '保存此图纸';

  @override
  String saved_write_again(String shortcut) {
    return '已保存 — 再按 $shortcut 可再次写入';
  }

  @override
  String get close_drawing => '关闭图纸';

  @override
  String get command_palette => '命令面板';

  @override
  String get hide_assistant => '隐藏助手';

  @override
  String get show_assistant => '显示助手';

  @override
  String get nothing_to_undo => '没有可撤销的操作';

  @override
  String get nothing_to_redo => '没有可重做的操作';

  @override
  String undo_named(String label) {
    return '撤销 $label';
  }

  @override
  String redo_named(String label) {
    return '重做 $label';
  }

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get more_file_actions => '更多文件操作';

  @override
  String get recent => '最近';

  @override
  String get remove_missing => '移除缺失项';

  @override
  String get clear_recent => '清空最近';

  @override
  String get recent_all_on_disk => '最近打开的文件都还在磁盘上。';

  @override
  String get recent_removed_one => '已从最近列表移除 1 个缺失文件。';

  @override
  String recent_removed_many(int count) {
    return '已从最近列表移除 $count 个缺失文件。';
  }

  @override
  String missing_path(String path) {
    return '缺失 — $path';
  }

  @override
  String missing_folder(String folder) {
    return '缺失 · $folder';
  }

  @override
  String get show_in_finder => '在 Finder 中显示';

  @override
  String get show_in_explorer => '在资源管理器中显示';

  @override
  String get show_in_folder => '在文件夹中显示';

  @override
  String could_not_reveal(String path, String error) {
    return '无法显示 $path：$error';
  }

  @override
  String could_not_open(String path, String error) {
    return '无法打开 $path：$error';
  }

  @override
  String copied_path(String path) {
    return '已复制 $path';
  }

  @override
  String open_drawings(int count) {
    return '已打开图纸（$count）';
  }

  @override
  String import_warnings_tooltip(int count) {
    return '$count 条导入警告 — 点击查看';
  }

  @override
  String get unsaved_drawing => '未保存的图纸';

  @override
  String unsaved_changes_path(String path) {
    return '未保存的更改 — $path';
  }

  @override
  String get close => '关闭';

  @override
  String get close_unsaved => '关闭 — 有未保存的更改';

  @override
  String get close_others => '关闭其他';

  @override
  String get close_all => '全部关闭';

  @override
  String get copy_path => '复制路径';

  @override
  String import_warnings(int count) {
    return '导入警告（$count）';
  }

  @override
  String get import_warning_title_one => '1 条导入警告';

  @override
  String import_warning_title_many(int count) {
    return '$count 条导入警告';
  }

  @override
  String copied_warnings(int count) {
    return '已复制 $count 条警告';
  }

  @override
  String get copy_all => '全部复制';

  @override
  String get minimise => '最小化';

  @override
  String get restore => '还原';

  @override
  String get maximise => '最大化';

  @override
  String get close_window => '关闭窗口';

  @override
  String get layers => '图层';

  @override
  String get properties => '特性';

  @override
  String get layouts => '布局';

  @override
  String get commands => '命令';

  @override
  String get extensions => '扩展';

  @override
  String get re_editor => '扩展编辑器';

  @override
  String get assistant => '助手';

  @override
  String get view_layers_hint => '当前图层、可见性与锁定';

  @override
  String get view_properties_hint => '查看并修改选择集';

  @override
  String get view_layouts_hint => '模型空间与图纸空间';

  @override
  String get view_commands_hint => '应用可执行的全部命令';

  @override
  String get view_history_hint => '已经执行过的命令';

  @override
  String get view_extensions_hint => '已安装扩展及其错误';

  @override
  String get view_editor_hint => '查看扩展源码';

  @override
  String hide_view(String label) {
    return '隐藏$label';
  }

  @override
  String get show_sidebar => '显示侧栏';

  @override
  String get hide_sidebar => '隐藏侧栏';

  @override
  String get resize_reset_width => '拖动调整宽度 · 双击恢复默认';

  @override
  String get resize_collapse => '拖动调整高度 · 双击折叠';

  @override
  String get resize_expand => '拖动调整高度 · 双击展开';

  @override
  String get cancel => '取消';

  @override
  String get dont_save => '不保存';

  @override
  String get continue_action => '继续';

  @override
  String get filter_commands => '按名称、别名或类别筛选';

  @override
  String get clear_filter => '清除筛选';

  @override
  String get no_commands_registered => '尚未注册任何命令。';

  @override
  String no_commands_match(String query) {
    return '没有匹配“$query”的命令。';
  }

  @override
  String get last_used => '最近使用';

  @override
  String get commands_count_one => '1 条命令';

  @override
  String commands_count_many(int count) {
    return '$count 条命令';
  }

  @override
  String get commands_matching => ' 匹配';

  @override
  String alias_named(String alias) {
    return '别名 $alias';
  }

  @override
  String get copy_and_dismiss => '点击复制并关闭';

  @override
  String get dismiss => '关闭';

  @override
  String get search_commands => '搜索命令、别名或类别';

  @override
  String get clear_search => '清除搜索';

  @override
  String get start_typing_command => '输入以查找命令。';

  @override
  String get try_alias_or_category => '可试别名 L、C、M，或类别如“绘图”。';

  @override
  String get palette_hints => '↑↓  移动   Enter  运行   Esc  关闭';

  @override
  String get last_badge => '最近';

  @override
  String get empty_tagline => 'AI 原生、插件化的二维 CAD';

  @override
  String get empty_github => 'GitHub 上的 FanCAD';

  @override
  String get open_drawing_file => '打开 DWG、DXF 或 FCB 文件';

  @override
  String get show_all_commands => '显示全部命令';

  @override
  String get command_history_hint => '命令历史将显示在这里。点击一行可重用，或按 ↑ 调出上次输入。';

  @override
  String get collapse_history => '折叠命令历史';

  @override
  String get expand_history => '展开命令历史';

  @override
  String get copied_history => '已复制命令历史';

  @override
  String get hint_click_or_type => '在图纸中拾取，或输入数值';

  @override
  String get hint_type_command => '输入命令';

  @override
  String get command_history => '命令历史';

  @override
  String get copy_history => '复制历史';

  @override
  String get clear_history => '清除历史';

  @override
  String get snap => '捕捉';

  @override
  String get ortho => '正交';

  @override
  String get polar => '极轴';

  @override
  String get grid => '栅格';

  @override
  String get snap_tooltip => '对象捕捉 (F3)。右键选择端点、中点…';

  @override
  String get ortho_tooltip => '限制为水平与垂直 (F8)';

  @override
  String polar_tooltip(int degrees) {
    return '极轴追踪 (F10) — $degrees°。右键更改增量';
  }

  @override
  String get grid_tooltip => '参考栅格 (F7)';

  @override
  String selected_count(int count) {
    return '已选 $count';
  }

  @override
  String get nothing_selected => '未选择对象';

  @override
  String get open_properties_selection => '打开选择集的特性';

  @override
  String objects_count(int count) {
    return '$count 个对象';
  }

  @override
  String get drawing_empty => '图纸为空';

  @override
  String get select_every_object => '选择全部对象';

  @override
  String get zoom_extents_tooltip => '范围缩放 — 使图纸适合窗口';

  @override
  String get scene_stats_tooltip => '视口中的批次 / 可见实体';

  @override
  String draw_calls_visible(int calls, int visible) {
    return '$calls 次绘制 · $visible 个可见';
  }

  @override
  String get restore_defaults => '恢复默认';

  @override
  String get layer_hidden => '隐藏';

  @override
  String get layer_locked => '锁定';

  @override
  String current_layer_named(String name) {
    return '当前图层“$name”';
  }

  @override
  String get current_layer_hint => '点击管理图层。右键可打开或解锁';

  @override
  String get turn_layer_on => '打开图层';

  @override
  String get turn_layer_off => '关闭图层';

  @override
  String get unlock_layer => '解锁图层';

  @override
  String get lock_layer => '锁定图层';

  @override
  String get manage_layers => '管理图层';

  @override
  String get cursor => '光标';

  @override
  String use_as_next_point(String text) {
    return '将 $text 用作下一点';
  }

  @override
  String copy_text(String text) {
    return '复制 $text';
  }

  @override
  String copied_text(String text) {
    return '已复制 $text';
  }

  @override
  String cancel_named(String name) {
    return '取消 $name';
  }

  @override
  String get erase => '删除';

  @override
  String get move => '移动';

  @override
  String get copy => '复制';

  @override
  String get copy_to_clipboard => '复制到剪贴板';

  @override
  String get copy_with_base => '带基点复制';

  @override
  String get cut => '剪切';

  @override
  String get paste => '粘贴';

  @override
  String get paste_to_original => '粘贴到原坐标';

  @override
  String get paste_as_block => '粘贴为块';

  @override
  String get isolate => '隔离';

  @override
  String get hide => '隐藏';

  @override
  String get deselect => '取消选择';

  @override
  String get select_all => '全部选择';

  @override
  String get zoom_extents => '范围缩放';

  @override
  String get zoom_window => '窗口缩放';

  @override
  String get zoom_to_selection => '缩放到选择集';

  @override
  String get show_hidden_objects => '显示隐藏对象';

  @override
  String get no_hidden_objects => '没有隐藏对象';

  @override
  String get one_object_hidden => '1 个对象已隐藏';

  @override
  String many_objects_hidden(int count) {
    return '$count 个对象已隐藏';
  }

  @override
  String get show_all => '全部显示';

  @override
  String get one_layer_off => '1 个图层已关闭';

  @override
  String many_layers_off(int count) {
    return '$count 个图层已关闭';
  }

  @override
  String get show_all_layers => '显示全部图层';

  @override
  String current_layer_locked(String name) {
    return '当前图层“$name”已锁定';
  }

  @override
  String get unlock => '解锁';

  @override
  String get assistant_canvas_locked => '助手正在操作，图纸暂不可编辑。';

  @override
  String get empty_drawing_title => '此图纸为空';

  @override
  String get empty_drawing_hint => '从工具栏开始命令，或输入别名如 L 或 C。';

  @override
  String get line_alias => '直线  L';

  @override
  String get rectangle_alias => '矩形  REC';

  @override
  String get circle_alias => '圆  C';

  @override
  String get restore_viewport => '恢复视口';

  @override
  String get rename => '重命名';

  @override
  String get duplicate => '复制';

  @override
  String get delete => '删除';

  @override
  String get new_layout => '新建布局';

  @override
  String get model_space => '模型空间';

  @override
  String paper_size_mm(String width, String height) {
    return '$width × $height mm';
  }

  @override
  String get viewport_one => '1 个视口';

  @override
  String viewport_many(int count) {
    return '$count 个视口';
  }

  @override
  String get viewport_maximised => '视口已最大化 — 点击还原';

  @override
  String get layout_right_click => '右键可重命名、复制或删除';

  @override
  String get delete_layout => '删除布局';

  @override
  String get new_paper_layout => '新建图纸空间布局';

  @override
  String click_to_change(String label) {
    return '点击修改$label';
  }

  @override
  String click_to_copy_label(String label) {
    return '点击复制$label';
  }

  @override
  String get layers_empty_workspace => '打开图纸以查看图层。';

  @override
  String get layouts_empty_workspace => '打开图纸以查看布局。';

  @override
  String get new_layer_current => '新建图层（并置为当前）';

  @override
  String get all_layers_on => '全部图层已打开';

  @override
  String get show_hidden_layers_one => '显示 1 个隐藏图层';

  @override
  String show_hidden_layers_many(int count) {
    return '显示 $count 个隐藏图层';
  }

  @override
  String get filter_layers => '筛选图层';

  @override
  String get no_layers => '此图纸没有图层。';

  @override
  String no_layers_match(String query) {
    return '没有匹配“$query”的图层。';
  }

  @override
  String get already_current => '已是当前图层';

  @override
  String get set_as_current => '设为当前';

  @override
  String get isolate_layer => '隔离图层';

  @override
  String get no_objects_on_layer => '此图层上没有对象';

  @override
  String get select_objects_one => '选择 1 个对象';

  @override
  String select_objects_many(int count) {
    return '选择 $count 个对象';
  }

  @override
  String get layer_0_cannot_delete => '图层 0 不能删除';

  @override
  String get delete_layer => '删除图层';

  @override
  String get current_layer_row_hint => '当前图层 — 双击隔离，右键查看更多';

  @override
  String get make_current_row_hint => '点击设为当前 — 双击隔离';

  @override
  String get properties_empty_workspace => '打开图纸以查看对象特性。';

  @override
  String get clear_selection => '清除选择';

  @override
  String get list_selection => '在命令历史中列出选择集';

  @override
  String get geometry => '几何';

  @override
  String get measurements => '测量';

  @override
  String get layer => '图层';

  @override
  String get colour => '颜色';

  @override
  String get line_type => '线型';

  @override
  String get lineweight => '线宽';

  @override
  String get start => '起点';

  @override
  String get length => '长度';

  @override
  String get angle => '角度';

  @override
  String get centre => '圆心';

  @override
  String get radius => '半径';

  @override
  String get diameter => '直径';

  @override
  String get circumference => '周长';

  @override
  String get start_angle => '起始角';

  @override
  String get end_angle => '终止角';

  @override
  String get total_angle => '总角度';

  @override
  String get vertices => '顶点';

  @override
  String get closed => '闭合';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get contents => '内容';

  @override
  String get position => '位置';

  @override
  String get height => '高度';

  @override
  String get rotation => '旋转';

  @override
  String get style => '样式';

  @override
  String get justify => '对正';

  @override
  String get width_factor => '宽度因子';

  @override
  String get oblique => '倾斜';

  @override
  String get column_width => '列宽';

  @override
  String get block => '块';

  @override
  String get scale => '比例';

  @override
  String get pattern => '图案';

  @override
  String get solid_fill => '实体填充';

  @override
  String get boundaries => '边界';

  @override
  String get measurement => '测量值';

  @override
  String get text => '文字';

  @override
  String get total_length => '总长度';

  @override
  String get total_area => '总面积';

  @override
  String get size => '尺寸';

  @override
  String get by_layer => '随层';

  @override
  String get by_block => '随块';

  @override
  String get default_value => '默认';

  @override
  String get hairline => '极细';

  @override
  String get drawing_empty_inspect => '此图纸为空。';

  @override
  String get click_object_inspect => '在画布上点击对象以查看特性。';

  @override
  String get nothing_to_clear => '没有可清除的内容';

  @override
  String get clear_conversation => '清除对话';

  @override
  String get new_chat => '新会话';

  @override
  String get chat_history => '会话';

  @override
  String get click_to_change_model => '点击更改模型或端点';

  @override
  String get assistant_profiles => '模型';

  @override
  String get add_assistant_profile => '添加模型';

  @override
  String get remove_assistant_profile => '删除模型';

  @override
  String get settings_test_model => '测试连接';

  @override
  String get assistant_profile_name => '显示名';

  @override
  String get ask_follow_up => '继续提问';

  @override
  String context_used(String used, String window) {
    return '$used / $window';
  }

  @override
  String get context_waiting => '首次回复后显示上下文占用';

  @override
  String get auto_approve => '自动批准删除';

  @override
  String get edits_without_asking => '删除将直接执行';

  @override
  String get ask_before_edits => '助手删除对象前先询问';

  @override
  String get custom_model => '自定义模型…';

  @override
  String get endpoint_ellipsis => '端点…';

  @override
  String get model => '模型';

  @override
  String get model_id => '任意模型名，例如 deepseek-chat';

  @override
  String get endpoint => '端点';

  @override
  String get assistant_empty_configured =>
      '可以询问图纸，或让助手修改。它使用与你相同的命令，一条回复对应一步撤销。';

  @override
  String get assistant_empty_unconfigured => '在设置中填入 API 密钥以连接模型，或将接口指向本地服务。';

  @override
  String get try_section => '试试';

  @override
  String get prompt_object_count => '这张图纸有多少个对象？';

  @override
  String get prompt_square => '在原点画一个 100 mm 的正方形';

  @override
  String get prompt_list_selection => '列出当前选择';

  @override
  String get click_to_copy => '点击复制';

  @override
  String get working => '正在处理…';

  @override
  String get thinking => '思考';

  @override
  String thinking_for(int seconds) {
    return '思考 ${seconds}s';
  }

  @override
  String allow_one_change(String title) {
    return '允许$title？';
  }

  @override
  String allow_n_changes(int count) {
    return '允许 $count 处更改？';
  }

  @override
  String affects_n_objects(int count) {
    return '影响 $count 个对象。';
  }

  @override
  String get ask_other => '其它…';

  @override
  String get ask_questions => '提问';

  @override
  String get ask_skip => '跳过';

  @override
  String get pin_selection => '将选择加入对话';

  @override
  String get mention_drawing => '提及图纸';

  @override
  String get no_open_drawings => '没有已打开的图纸';

  @override
  String get pin_into_chat => '加入对话';

  @override
  String get ask_assistant => '询问助手  Enter 发送';

  @override
  String get ask_assistant_unavailable => '模型不可用，请先在设置中配置';

  @override
  String get stop => '停止';

  @override
  String get send_enter => '发送  Enter';

  @override
  String get open_extensions_folder => '打开扩展文件夹';

  @override
  String get create_extension => '创建扩展';

  @override
  String get reload_all_extensions => '重新加载全部扩展';

  @override
  String get extensions_unavailable => '扩展不可用：本次会话未配置扩展文件夹。';

  @override
  String get no_extensions_installed =>
      '尚未安装扩展。可创建一个，或将含 fancad.plugin.json 的文件夹放入扩展目录。';

  @override
  String get edit_source => '编辑源码';

  @override
  String get enable_extension => '启用扩展';

  @override
  String get disable_extension => '禁用扩展';

  @override
  String get reload => '重新加载';

  @override
  String get state => '状态';

  @override
  String get folder => '文件夹';

  @override
  String get permissions => '权限';

  @override
  String get log => '日志';

  @override
  String get plugin_running => '运行中';

  @override
  String get plugin_starting => '启动中';

  @override
  String get plugin_failed => '失败';

  @override
  String get plugin_disabled => '已禁用';

  @override
  String get plugin_installed => '已安装';

  @override
  String get unsaved_editor_changes => '编辑器有未保存更改';

  @override
  String editor_file_dirty(String name) {
    return '“$name” 有尚未写入的修改。';
  }

  @override
  String get nothing_to_save => '没有可保存的内容';

  @override
  String get save_and_reload => '保存并重新加载';

  @override
  String get saved => '已保存';

  @override
  String get extension => '扩展';

  @override
  String get editor_unavailable => '扩展不可用：未配置扩展文件夹。';

  @override
  String get create_extension_first => '请先创建扩展，再在此打开。';

  @override
  String get choose_extension => '请在上方选择扩展，或从扩展面板使用“编辑源码”。';

  @override
  String no_such_file(String name) {
    return '没有此文件：$name';
  }

  @override
  String plugin_not_installed(String id) {
    return '$id 未安装';
  }

  @override
  String get snap_endpoint => '端点';

  @override
  String get snap_midpoint => '中点';

  @override
  String get snap_center => '圆心';

  @override
  String get snap_quadrant => '象限点';

  @override
  String get snap_intersection => '交点';

  @override
  String get snap_perpendicular => '垂足';

  @override
  String get snap_tangent => '切点';

  @override
  String get snap_node => '节点';

  @override
  String get snap_nearest => '最近点';

  @override
  String get category_file => '文件';

  @override
  String get category_draw => '绘图';

  @override
  String get category_modify => '修改';

  @override
  String get category_view => '视图';

  @override
  String get category_select => '选择';

  @override
  String get category_layers => '图层';

  @override
  String get category_inquiry => '查询';

  @override
  String get category_output => '输出';

  @override
  String get category_extensions => '扩展';

  @override
  String get command_file_new => '新建图纸';

  @override
  String get command_file_open => '打开...';

  @override
  String get command_file_save => '保存';

  @override
  String get command_file_save_as => '另存为...';

  @override
  String get command_file_close => '关闭图纸';

  @override
  String get command_file_open_recent => '打开最近文件';

  @override
  String get command_file_audit => '保真审核';

  @override
  String get command_draw_line => '直线';

  @override
  String get command_draw_polyline => '多段线';

  @override
  String get command_draw_spline => '样条曲线';

  @override
  String get command_draw_rectangle => '矩形';

  @override
  String get command_draw_circle => '圆';

  @override
  String get command_draw_circle_2p => '圆（两点）';

  @override
  String get command_draw_circle_3p => '圆（三点）';

  @override
  String get command_draw_circle_ttr => '圆（相切、相切、半径）';

  @override
  String get command_draw_donut => '圆环';

  @override
  String get command_draw_arc => '圆弧';

  @override
  String get command_draw_polygon => '多边形';

  @override
  String get command_draw_ellipse => '椭圆';

  @override
  String get command_draw_xline => '构造线';

  @override
  String get command_draw_ray => '射线';

  @override
  String get command_draw_point => '点';

  @override
  String get command_draw_divide => '定数等分';

  @override
  String get command_draw_measure => '定距等分';

  @override
  String get command_draw_text => '单行文字';

  @override
  String get command_draw_mtext => '多行文字';

  @override
  String get command_draw_leader => '引线';

  @override
  String get command_draw_hatch => '填充';

  @override
  String get command_draw_dim_linear => '线性标注';

  @override
  String get command_draw_dim_aligned => '对齐标注';

  @override
  String get command_draw_dim_radius => '半径标注';

  @override
  String get command_draw_dim_diameter => '直径标注';

  @override
  String get command_draw_center_mark => '圆心标记';

  @override
  String get command_draw_center_line => '中心线';

  @override
  String get command_draw_dim_angular => '角度标注';

  @override
  String get command_draw_dim_continue => '连续标注';

  @override
  String get command_draw_dim_baseline => '基线标注';

  @override
  String get command_annot_dimstyle => '标注样式';

  @override
  String get command_annot_textstyle => '文字样式';

  @override
  String get command_edit_erase => '删除';

  @override
  String get command_edit_overkill => '删除重复';

  @override
  String get command_edit_move => '移动';

  @override
  String get command_edit_copy => '复制';

  @override
  String get command_edit_copy_clip => '复制到剪贴板';

  @override
  String get command_edit_copy_base => '带基点复制';

  @override
  String get command_edit_cut_clip => '剪切';

  @override
  String get command_edit_paste_clip => '粘贴';

  @override
  String get command_edit_paste_orig => '粘贴到原坐标';

  @override
  String get command_edit_paste_block => '粘贴为块';

  @override
  String get command_edit_stretch => '拉伸';

  @override
  String get command_edit_rotate => '旋转';

  @override
  String get command_edit_scale => '缩放';

  @override
  String get command_edit_mirror => '镜像';

  @override
  String get command_edit_align => '对齐';

  @override
  String get command_edit_array => '矩形阵列';

  @override
  String get command_edit_polar_array => '环形阵列';

  @override
  String get command_edit_offset => '偏移';

  @override
  String get command_edit_trim => '修剪';

  @override
  String get command_edit_extend => '延伸';

  @override
  String get command_edit_fillet => '圆角';

  @override
  String get command_edit_chamfer => '倒角';

  @override
  String get command_edit_break => '打断';

  @override
  String get command_edit_lengthen => '拉长';

  @override
  String get command_edit_explode => '分解';

  @override
  String get command_edit_block => '块';

  @override
  String get command_edit_insert => '插入';

  @override
  String get command_edit_minsert => '阵列插入';

  @override
  String get command_block_purge => '清理未用块';

  @override
  String get command_block_rename => '重命名块';

  @override
  String get command_edit_join => '合并';

  @override
  String get command_edit_close => '闭合多段线';

  @override
  String get command_edit_open => '打开多段线';

  @override
  String get command_edit_polyline_width => '多段线宽度';

  @override
  String get command_edit_hatch => '编辑填充';

  @override
  String get command_edit_to_polyline => '转换为多段线';

  @override
  String get command_edit_reverse => '反转';

  @override
  String get command_edit_undo => '撤销';

  @override
  String get command_edit_redo => '重做';

  @override
  String get command_edit_change_layer => '更改图层';

  @override
  String get command_edit_change_color => '更改颜色';

  @override
  String get command_edit_change_linetype => '更改线型';

  @override
  String get command_edit_change_lineweight => '更改线宽';

  @override
  String get command_edit_dimension_text => '标注文字';

  @override
  String get command_edit_dim_tedit => '移动标注文字';

  @override
  String get command_edit_text_content => '编辑文字';

  @override
  String get command_edit_text_object => '编辑文字对象';

  @override
  String edit_text_object_window(String entity) {
    return '编辑 $entity';
  }

  @override
  String get command_edit_justify_text => '文字对正';

  @override
  String get command_edit_match_prop => '特性匹配';

  @override
  String get command_view_zoom_extents => '范围缩放';

  @override
  String get command_view_zoom_window => '窗口缩放';

  @override
  String get command_view_zoom_in => '放大';

  @override
  String get command_view_zoom_out => '缩小';

  @override
  String get command_view_zoom_selected => '缩放到选择集';

  @override
  String get command_view_regen => '重生成';

  @override
  String get command_workbench_preferences => '设置...';

  @override
  String get command_select_all => '全部选择';

  @override
  String get command_select_none => '取消全部选择';

  @override
  String get command_select_invert => '反向选择';

  @override
  String get command_select_similar => '选择类似';

  @override
  String get command_select_by_layer => '按图层选择';

  @override
  String get command_select_by_color => '按颜色选择';

  @override
  String get command_select_by_linetype => '按线型选择';

  @override
  String get command_select_by_lineweight => '按线宽选择';

  @override
  String get command_select_by_type => '按类型选择';

  @override
  String get command_select_by_block => '按块选择';

  @override
  String get command_view_isolate_objects => '隔离对象';

  @override
  String get command_view_hide_objects => '隐藏对象';

  @override
  String get command_view_unisolate_objects => '取消隔离对象';

  @override
  String get command_layer_new => '新建图层';

  @override
  String get command_layer_set_current => '设置当前图层';

  @override
  String get command_layer_toggle_visible => '切换图层可见性';

  @override
  String get command_layer_isolate => '隔离图层';

  @override
  String get command_layer_show_all => '显示全部图层';

  @override
  String get command_layer_toggle_lock => '切换图层锁定';

  @override
  String get command_layer_delete => '删除图层';

  @override
  String get command_layer_purge => '清理未用图层';

  @override
  String get command_query_summary => '图纸摘要';

  @override
  String get command_query_list => '列表';

  @override
  String get command_query_entities => '查询实体';

  @override
  String get command_query_selection => '查询选择集';

  @override
  String get command_query_viewport => '查询视口';

  @override
  String get command_query_id => '点坐标';

  @override
  String get command_query_distance => '距离';

  @override
  String get command_query_angle => '角度';

  @override
  String get command_query_area => '面积';

  @override
  String get command_query_layers => '列出图层';

  @override
  String get command_layout_list => '列出布局';

  @override
  String get command_layout_set => '设置布局';

  @override
  String get command_layout_new => '新建布局';

  @override
  String get command_layout_delete => '删除布局';

  @override
  String get command_layout_copy => '复制布局';

  @override
  String get command_layout_rename => '重命名布局';

  @override
  String get command_layout_order => '布局顺序';

  @override
  String get command_layout_pagesetup => '页面设置';

  @override
  String get command_layout_mview => '创建视口';

  @override
  String get command_layout_vpscale => '视口比例';

  @override
  String get command_layout_vplock => '视口锁定';

  @override
  String get command_layout_vpon => '打开视口';

  @override
  String get command_layout_vplayer => '视口图层冻结';

  @override
  String get command_layout_vpmax => '最大化视口';

  @override
  String get command_layout_vpmin => '最小化视口';

  @override
  String get command_print_export_svg => '导出 SVG';

  @override
  String get command_print_export_pdf => '导出 PDF';

  @override
  String get command_xref_attach => '附着外部参照';

  @override
  String get command_xref_reload => '重载外部参照';

  @override
  String get command_xref_detach => '拆离外部参照';

  @override
  String get command_xref_bind => '绑定外部参照';

  @override
  String get command_plugins_list => '列出扩展';

  @override
  String get command_plugins_reload => '重新加载扩展';

  @override
  String get command_plugins_enable => '启用扩展';

  @override
  String get command_plugins_disable => '禁用扩展';

  @override
  String get command_plugins_logs => '显示扩展日志';

  @override
  String get command_plugins_scaffold => '创建扩展';

  @override
  String get command_plugins_write => '写入扩展文件';

  @override
  String get command_plugins_read => '读取扩展文件';

  @override
  String get command_plugins_typings => '写入插件 API 类型';

  @override
  String get command_plugins_edit => '编辑扩展文件';

  @override
  String get command_plugins_eval => '在扩展中求值';

  @override
  String get command_file_list => '列出图纸';

  @override
  String get command_file_activate => '激活图纸';

  @override
  String get command_draw_attdef => '属性定义';

  @override
  String get command_edit_attedit => '编辑属性';

  @override
  String get command_view_units => '单位';

  @override
  String get command_file_new_desc => '在新标签页中创建空图形。';

  @override
  String get command_file_open_desc => '打开 DWG 或 DXF 文件。';

  @override
  String get command_file_save_desc => '保存此命令所针对的图形；从未保存过时会询问路径。';

  @override
  String get command_file_save_as_desc => '将此命令所针对的图形保存到新文件。';

  @override
  String get command_file_close_desc => '关闭此命令所针对的图形。';

  @override
  String get command_file_open_recent_desc => '重新打开最近用过的文件。';

  @override
  String get command_file_audit_desc => '把图形写到临时 DXF，并报告往返会丢失的内容。';

  @override
  String get command_file_list_desc =>
      '列出每个打开的图纸标签页：id、标题、路径、是否已修改、是否为当前、实体数量和当前布局。用 id 作为 fancad 的标签选择器，即可不切换界面操作某张图。';

  @override
  String get command_file_activate_desc =>
      '把已打开的图纸带到前台。传入 file.list 的 id，或唯一的路径或标题。';

  @override
  String get command_draw_line_desc => '绘制一条或多条相连的直线段。提供起点和终点可非交互地画单段。';

  @override
  String get command_draw_polyline_desc => '将相连的线段画成一条多段线。传入点数组可非交互创建。';

  @override
  String get command_draw_spline_desc =>
      '绘制夹紧 B 样条。控制点模式把曲线拉向单击处，只保证两端；拟合模式穿过每一点。传入点数组可非交互创建。';

  @override
  String get command_draw_rectangle_desc => '将轴对齐矩形画成闭合多段线。';

  @override
  String get command_draw_circle_desc => '由圆心和半径绘制圆。';

  @override
  String get command_draw_circle_2p_desc => '以两点连线为直径绘制圆。';

  @override
  String get command_draw_circle_3p_desc => '绘制过指定三点的唯一圆。';

  @override
  String get command_draw_circle_ttr_desc =>
      '绘制给定半径、与两条直线/圆/圆弧相切的圆。在每个对象上的拾取决定侧向（对圆还区分外切与内切）。';

  @override
  String get command_draw_donut_desc =>
      '由内径和外径绘制填充圆环。内径为零则是实心圆盘。结果是闭合的宽多段线，与 DWG 中圆环的存法一致。';

  @override
  String get command_draw_arc_desc => '通过三点绘制圆弧：起点、圆弧上一点、终点。';

  @override
  String get command_draw_polygon_desc => '绘制内接于圆的正多边形。';

  @override
  String get command_draw_ellipse_desc => '由中心、一条轴的端点、到另一条轴的距离绘制椭圆。';

  @override
  String get command_draw_xline_desc => '过一点沿给定方向绘制无限构造线。第二点只定角度；两侧无限延伸。';

  @override
  String get command_draw_ray_desc => '从起点穿过第二点绘制半无限射线。与构造线不同，它有起点。';

  @override
  String get command_draw_point_desc => '放置点标记。';

  @override
  String get command_draw_divide_desc =>
      '在直线、多段线、圆弧或圆上放置等分点标记。开口对象不标记端点；圆或闭合多段线在每一等分处放置标记。凸度按圆弧走，不按弦。';

  @override
  String get command_draw_measure_desc =>
      '沿直线、多段线、圆弧或圆按固定间距放置点标记。开口对象从较近一端开始；圆从拾取点开始。不标记端点。凸度按圆弧走，不按弦。';

  @override
  String get command_draw_text_desc =>
      '放置单行文字。样式默认为当前 TEXTSTYLE。对正为 Left、Center、Right 或如 TL 的角点代码。';

  @override
  String get command_draw_mtext_desc =>
      '放置多行文字。换行变为 \\P。宽度 0 不换行。对正为 TL…BR 或附着点 1–9（1 为左上）。';

  @override
  String get command_draw_attdef_desc =>
      '放置属性定义。把它放进块后，INSERT 和 ATTEDIT 才能填写该标签，用于标题栏和明细表。';

  @override
  String get command_draw_leader_desc =>
      '从箭头尖经过一个或多个顶点绘制引线。可选注释文字落在末点的水平着陆线上，与 AutoCAD LEADER 的标注方式相同。';

  @override
  String get command_draw_hatch_desc => '填充内部点周围的区域，或选定闭合边界围成的区域。四条相接的直线仍算作边界。';

  @override
  String get command_draw_dim_linear_desc =>
      '放置水平或垂直标注。尺寸线拾取决定轴向：原点上方或下方测宽度，左侧或右侧测高度。一条直线可代替两个原点。';

  @override
  String get command_draw_dim_aligned_desc =>
      '放置与两原点平行的标注。文字是真实距离，不是水平或垂直分量。一条直线可代替两个原点。';

  @override
  String get command_draw_dim_radius_desc =>
      '在圆或圆弧上放置半径标注。第二次拾取是箭头尖；文字为半径，前缀 R。';

  @override
  String get command_draw_dim_diameter_desc =>
      '在圆或圆弧上放置直径标注。第二次拾取是箭头尖；文字为直径，前缀 Ø。';

  @override
  String get command_draw_center_mark_desc =>
      '在选定圆或圆弧上绘制圆心标记。中心处为短十字；可选延长线越过圆周，即常见的 DIMCENTER。';

  @override
  String get command_draw_center_line_desc =>
      '在两条平行线之间，或两个圆/圆弧的圆心之间绘制中心线。线段跨越两个对象并略微伸出两端。';

  @override
  String get command_draw_dim_angular_desc =>
      '放置角度标注。拾取圆弧则圆心为顶点；拾取两条直线则交点为顶点；最后一拾取落在尺寸弧上并选择标注哪个扇区。提供顶点时三点方式仍可用。';

  @override
  String get command_draw_dim_continue_desc =>
      '从上一条的第二原点放置下一条线性或对齐标注，共用同一尺寸线。连续指定下一点可沿一排特征走。';

  @override
  String get command_draw_dim_baseline_desc =>
      '从同一第一原点放置下一条线性或对齐标注，尺寸线向外错开。连续指定下一点可叠放总体尺寸。';

  @override
  String get command_annot_dimstyle_desc =>
      '创建或编辑标注样式。重新生成的标注从命名样式读取文字高度、箭头大小、尺寸界线偏移、比例和小数位数。省略名称则列出样式，或编辑当前样式。';

  @override
  String get command_annot_textstyle_desc =>
      '创建或编辑文字样式。新建 TEXT 和 MTEXT 从命名样式读取字体、固定高度、宽度因子和倾斜角。省略名称则列出样式，或编辑当前样式。';

  @override
  String get command_edit_erase_desc => '删除选定对象。';

  @override
  String get command_edit_overkill_desc =>
      '删除完全重合的几何副本，并把重叠或首尾相接的共线直线收成一笔。保留第一份并拉到并集。省略 ids 表示整个当前空间，以免残留选择集挡住其余重复。';

  @override
  String get command_edit_move_desc => '按位移移动选定对象。';

  @override
  String get command_edit_copy_desc => '将选定对象复制到一个或多个位置。每指定一个第二点就再放一份。';

  @override
  String get command_edit_copy_clip_desc =>
      '将选定对象复制到剪贴板。选择集左下角为粘贴基点。可用 PASTECLIP 粘到本图或其他标签页。';

  @override
  String get command_edit_copy_base_desc =>
      '将选定对象复制到剪贴板，并指定基点，以便 PASTECLIP 把该点落到插入处。';

  @override
  String get command_edit_cut_clip_desc =>
      '将选定对象复制到剪贴板并从图形中删除。锁定图层上的对象留下；剪贴板仍持有副本。';

  @override
  String get command_edit_paste_clip_desc => '在插入点粘贴剪贴板对象。存储的基点落到该单击处。';

  @override
  String get command_edit_paste_orig_desc => '按源图中的坐标粘贴剪贴板对象，不再询问插入点。';

  @override
  String get command_edit_paste_block_desc => '将剪贴板对象作为匿名块参照粘贴。存储的基点落到所拾取的插入点。';

  @override
  String get command_edit_stretch_desc => '移动跨越窗口内的顶点，其余锚定。窗口完全包住的对象整体移动。';

  @override
  String get command_edit_rotate_desc => '绕基点旋转选定对象。角度以度为单位，逆时针。';

  @override
  String get command_edit_scale_desc => '绕基点均匀缩放选定对象。';

  @override
  String get command_edit_mirror_desc => '将选定对象沿一条直线镜像。';

  @override
  String get command_edit_align_desc =>
      '移动选择集，使源点落到目标点。第二对点按两个方向旋转对齐；可选缩放匹配两段长度。';

  @override
  String get command_edit_array_desc => '将选定对象复制成矩形阵列。';

  @override
  String get command_edit_polar_array_desc =>
      '绕中心旋转复制选定对象。填充 360° 则沿整圆均分；更小的填充从原对象起包含该角。';

  @override
  String get command_edit_offset_desc => '按固定距离创建直线、圆弧、圆和多段线的平行副本。';

  @override
  String get command_edit_trim_desc =>
      '将直线、多段线或圆弧缩短到与选定剪切边的交点。包含拾取点的部分被去掉。闭合多段线会打开；凸度在圆弧上切，不在弦上切。';

  @override
  String get command_edit_extend_desc =>
      '延长直线、开口多段线或圆弧，直到碰到选定边界边。凸度沿其所在圆增长。多段线或圆弧上的拾取决定移动哪一端。';

  @override
  String get command_edit_fillet_desc =>
      '用给定半径的圆弧圆角两条直线之间的角，或多段线顶点。传入 all=true 可圆角多段线每个直角。半径为零则修剪或延伸成尖角。';

  @override
  String get command_edit_chamfer_desc =>
      '在两条直线之间，或多段线顶点处切出直线倒角。传入 all=true 可倒每个直角。距离为零则修剪或延伸成尖角。';

  @override
  String get command_edit_break_desc =>
      '在一点打断直线、多段线或圆弧，或删除两点之间的部分。凸度拆成两段较小圆弧。圆需要两点，保留从第二次拾取逆时针回到第一点的残余。省略第二点则只打断（圆弧和开口链）。';

  @override
  String get command_edit_lengthen_desc =>
      '通过移动所拾取的一端，改变直线、开口多段线或圆弧的长度。凸度沿圆弧增减。可指定总长，或带符号增量加到当前长度。圆弧不能闭合成整圆。';

  @override
  String get command_edit_explode_desc =>
      '将多段线打成线段，将块参照打成其内容的副本，将标注打成所绘的线、箭头和文字。';

  @override
  String get command_edit_block_desc =>
      '用选定对象定义命名块，并在基点用一个插入替换它们，图面看起来不变，之后还能再次插入该定义。';

  @override
  String get command_edit_insert_desc =>
      '放置一个或多个命名块参照。缩放为均匀缩放；旋转以度为单位。传入点数组可在多处盖同一块。';

  @override
  String get command_edit_minsert_desc =>
      '将命名块的矩形阵列作为一次插入放置。这些副本仍是一个对象，移动插入即移动整组。';

  @override
  String get command_block_purge_desc =>
      '删除没有任何插入引用的命名块定义。同一轮也会清掉套在其中的未用定义。外部参照和布局块不动。';

  @override
  String get command_block_rename_desc =>
      '重命名块定义，并更新仍指向旧名的所有插入。布局块、匿名块和外部参照不能重命名。';

  @override
  String get command_edit_join_desc =>
      '将端点相接的选定直线、圆弧和开口多段线接成一条多段线。相接方向相反时该段会反向；两端相接的环存为闭合。';

  @override
  String get command_edit_close_desc => '连接末顶点与第一顶点，闭合选定的开口多段线。已经闭合的不动。';

  @override
  String get command_edit_open_desc => '去掉闭合段，打开选定的闭合多段线。顶点保留，只断开闭环。';

  @override
  String get command_edit_polyline_width_desc =>
      '设置选定多段线的恒定宽度。零为细线；圆环用同一字段，因此画完后改宽线也走这里。';

  @override
  String get command_edit_hatch_desc => '更改选定填充的图案、比例或角度。省略某字段则保持原值。角度以度为单位。';

  @override
  String get command_edit_to_polyline_desc => '将选定直线变成两顶点多段线，以便作为链闭合、打开或反向。';

  @override
  String get command_edit_reverse_desc =>
      '反转选定直线和多段线的方向。形状不变，起终点对调，对线型和沿链行走的命令有意义。';

  @override
  String get command_edit_undo_desc => '撤销最近一次更改。';

  @override
  String get command_edit_redo_desc => '重新应用最近撤销的更改。';

  @override
  String get command_edit_change_layer_desc => '将选定对象移到另一图层。';

  @override
  String get command_edit_change_color_desc =>
      '设置选定对象的颜色。接受 AutoCAD 颜色索引（1–255）、#rrggbb 或 ByLayer。';

  @override
  String get command_edit_change_linetype_desc =>
      '设置选定对象的线型。库存名（DASHED、HIDDEN、CENTER、PHANTOM、DOT、DASHDOT、DIVIDE、Continuous）以及 ByLayer、ByBlock 均可。';

  @override
  String get command_edit_change_lineweight_desc =>
      '设置选定对象的线宽。接受毫米值（0.25）、百分之一毫米（25）、ByLayer、ByBlock、Default 或 hairline。';

  @override
  String get command_edit_dimension_text_desc =>
      '覆盖选定标注的文字。空则恢复测量值；<> 代表该值；单个空格隐藏文字。';

  @override
  String get command_edit_dim_tedit_desc =>
      '将选定标注的文字移到新位置。线性标注的尺寸线跟随移动且不交换宽高；对齐、径向和角度标注保持类型。';

  @override
  String get command_edit_text_content_desc =>
      '更改选定文字、多行文字、标注、属性或引线的内容。对标注，空则恢复测量值。';

  @override
  String get command_edit_text_object_desc =>
      '在一次撤销中更新选定文字、多行文字、属性或引线的内容、高度、颜色、对正、旋转、样式、列宽、宽度因子或倾斜。标注文字高度是标注样式属性，会被忽略。';

  @override
  String get command_edit_justify_text_desc =>
      '更改选定文字或多行文字的对正，并移动插入点使字形留在原处。不提供 Align 和 Fit，它们需要第二点。';

  @override
  String get command_edit_match_prop_desc =>
      '将源对象的图层、颜色、线型、线宽及其他显示特性复制到目标对象。可见性不动，以免破坏隔离和隐藏。';

  @override
  String get command_edit_attedit_desc => '更改块参照上的属性值。常量标签保持定义中的写法。';

  @override
  String get command_view_zoom_extents_desc => '使整个图形适应窗口。';

  @override
  String get command_view_zoom_window_desc => '缩放到指定的矩形。';

  @override
  String get command_view_zoom_in_desc => '以视图中心放大。';

  @override
  String get command_view_zoom_out_desc => '以视图中心缩小。';

  @override
  String get command_view_zoom_selected_desc => '使选定对象适应窗口。';

  @override
  String get command_view_regen_desc => '重建显示列表，丢弃缓存的曲线细分。';

  @override
  String get command_view_units_desc =>
      '设置写入 \$INSUNITS 的图形插入单位。坐标仍用这些单位；该值供导入器和查询做换算。';

  @override
  String get command_workbench_preferences_desc => '打开应用程序设置对话框。';

  @override
  String get command_select_all_desc => '选择当前空间中每个可选对象。';

  @override
  String get command_select_none_desc => '清除选择。';

  @override
  String get command_select_invert_desc => '选择当前未选中的所有对象。';

  @override
  String get command_select_similar_desc => '把选择扩展到同一类型和图层的每个对象。';

  @override
  String get command_select_by_layer_desc => '选择指定图层上的每个对象。';

  @override
  String get command_select_by_color_desc =>
      '选择存储颜色匹配 ACI、#rrggbb、ByLayer 或 ByBlock 的每个对象。图层继承的红与 ACI 1 不是一回事。';

  @override
  String get command_select_by_linetype_desc =>
      '选择存储线型匹配给定名称、ByLayer 或 ByBlock 的每个对象。';

  @override
  String get command_select_by_lineweight_desc =>
      '选择存储线宽匹配毫米值、百分之一毫米、ByLayer、ByBlock、Default 或 hairline 的每个对象。图层继承的 0.25 mm 与 25 不是一回事。';

  @override
  String get command_select_by_type_desc =>
      '选择当前空间中某一种实体。LINE、CIRCLE、INSERT、DIMENSION 及其他 FanCAD 类型可用；LWPOLYLINE 和 BLOCK 分别当作多段线和插入。';

  @override
  String get command_select_by_block_desc =>
      '选择当前空间中某个命名块的每一次插入。名称不区分大小写，与 INSERT 和 RENAME 的查找方式相同。';

  @override
  String get command_view_isolate_objects_desc =>
      '隐藏当前空间中除选择集以外的每个对象，让其余图形让开但并不删除。';

  @override
  String get command_view_hide_objects_desc => '隐藏选定对象而不删除。';

  @override
  String get command_view_unisolate_objects_desc => '显示当前空间中被隔离或隐藏关掉的每个对象。';

  @override
  String get command_layer_new_desc => '创建图层并设为当前。';

  @override
  String get command_layer_set_current_desc => '选择新建对象所在的图层。';

  @override
  String get command_layer_toggle_visible_desc => '打开或关闭图层。';

  @override
  String get command_layer_isolate_desc => '关闭除指定图层外的所有图层。';

  @override
  String get command_layer_show_all_desc => '重新打开所有图层。';

  @override
  String get command_layer_toggle_lock_desc => '锁定或解锁图层。锁定图层上的对象仍可见，但不能修改。';

  @override
  String get command_layer_delete_desc => '删除图层及其上的所有对象。名为 0 的图层不能删除。';

  @override
  String get command_layer_purge_desc =>
      '删除没有任何对象使用的图层。图层 0 保留；若当前图层为空，先切回 0 再清理。';

  @override
  String get command_query_summary_desc =>
      '返回图形的紧凑统计：范围、按类型的实体计数、以及每层计数。查询内容前先用它了解图纸。';

  @override
  String get command_query_list_desc => '报告选定对象的完整特性。';

  @override
  String get command_query_entities_desc =>
      '按可选过滤器查找实体，返回其 id 和特性。用图层、类型和包围窗口把大图缩到关心的部分。';

  @override
  String get command_query_selection_desc =>
      '将当前选择集作为结构化记录返回（id、类型、图层、范围、简要几何）。用它代替猜测 id。空选择是成功的空列表，不是提示。';

  @override
  String get command_query_viewport_desc =>
      '返回活动相机：中心、比例和可见窗口 [minX, minY, maxX, maxY]。把该窗口传给 query.entities 可列出用户正在看的内容。';

  @override
  String get command_query_id_desc => '报告一点的 X、Y 坐标。需要位置而不是两点距离时用此命令。';

  @override
  String get command_query_distance_desc => '测量两点之间的距离和角度。';

  @override
  String get command_query_angle_desc => '测量顶点处两条射线的夹角。第一点是顶点；后两点定义两边。';

  @override
  String get command_query_area_desc => '报告选定闭合对象的面积和周长。';

  @override
  String get command_query_layers_desc => '返回每个图层及其状态和对象数量。';

  @override
  String get command_layout_list_desc => '列出模型和图纸空间布局及其视口。';

  @override
  String get command_layout_set_desc => '切换活动布局（模型或图纸标签）。';

  @override
  String get command_layout_new_desc =>
      '添加图纸空间布局标签页并打开。图纸默认为 A4 横向；可传入宽高（毫米）覆盖。';

  @override
  String get command_layout_delete_desc =>
      '删除图纸空间布局标签页及该页上的实体。不能删除模型。省略名称则删除当前标签页。';

  @override
  String get command_layout_copy_desc => '复制图纸空间布局：图纸尺寸、视口以及该页上的实体。不能复制模型。';

  @override
  String get command_layout_rename_desc => '重命名图纸布局标签。图纸、视口和图纸实体不动。不能重命名模型。';

  @override
  String get command_layout_order_desc =>
      '在布局条中移动图纸标签。模型始终第一。index 是在图纸标签中的目标位置（0 为第一张图纸）。也可传入 before / after 另一标签名。';

  @override
  String get command_layout_pagesetup_desc =>
      '更改布局的图纸尺寸（毫米）、打印旋转（0、90、180 或 270）、比例或适应图纸、偏移以及可选打印窗口。省略名称则编辑当前图纸标签。模型没有图纸。';

  @override
  String get command_layout_mview_desc =>
      '在当前图纸布局上开一个看向模型空间的窗口。除非提供比例，否则模型会框进该矩形。';

  @override
  String get command_layout_vpscale_desc =>
      '设置图纸视口的比例（每个图纸单位对应的模型单位）。传入 fit=true 则重新框住模型。锁定的视口会被拒绝。';

  @override
  String get command_layout_vplock_desc =>
      '锁定或解锁图纸视口，使 VPSCALE 不能改视图。省略 locked 则切换。窗口边框仍可移动。';

  @override
  String get command_layout_vpon_desc =>
      '打开或关闭图纸视口。关闭的窗口保留边框但隐藏模型，打印时跳过。省略 on 则切换。';

  @override
  String get command_layout_vplayer_desc =>
      '在一个图纸视口中冻结或解冻图层。其他窗口和模型空间保持各自的可见性。省略 freeze 则冻结。';

  @override
  String get command_layout_vpmax_desc => '按图纸视口框入模型空间，以便通过该窗口编辑模型。VPMIN 返回图纸。';

  @override
  String get command_layout_vpmin_desc => '返回 VPMAX 离开的图纸布局并框住该页。';

  @override
  String get command_print_export_svg_desc =>
      '将布局打印为 SVG 文件。省略布局名则打印当前标签页。路径为 .pdf 则改为矢量 PDF。传入 corner1 和 corner2 可打印窗口；否则使用布局存储的打印窗口或整张图纸。';

  @override
  String get command_print_export_pdf_desc =>
      '将布局打印为矢量 PDF。省略布局名则打印当前标签页。图纸尺寸成为页面 MediaBox；视口被裁剪。传入 corner1 和 corner2 可打印窗口。';

  @override
  String get command_xref_attach_desc =>
      '将另一图纸作为外部参照加载并放到模型空间。再次附着同一路径即重新加载；已有插入保持位置。';

  @override
  String get command_xref_reload_desc =>
      '从存储路径重新读取已附着的外部参照。省略名称则重载选定的外部参照，或图中唯一的外部参照。';

  @override
  String get command_xref_detach_desc =>
      '移除外部参照以及显示它的每次插入。省略名称则拆离选定的外部参照，或图中唯一的外部参照。';

  @override
  String get command_xref_bind_desc =>
      '把外部参照变成本地块，图形不再依赖该文件。插入位置不变。省略名称则绑定选定的外部参照，或图中唯一的外部参照。';

  @override
  String get command_plugins_list_desc => '列出已安装扩展及其状态、版本和所贡献的命令。';

  @override
  String get command_plugins_reload_desc => '从磁盘重新读取扩展并重新求值，无需重启即可拿到代码和清单的更改。';

  @override
  String get command_plugins_enable_desc => '加载扩展，使其可以再次贡献命令。';

  @override
  String get command_plugins_disable_desc => '卸载扩展，在重新启用前不再激活。';

  @override
  String get command_plugins_logs_desc => '打印扩展记录的日志，用于排查失败。';

  @override
  String get command_plugins_scaffold_desc =>
      '写入带清单和可运行 main.js 的新扩展文件夹并加载。返回写入的路径。';

  @override
  String get command_plugins_write_desc => '覆盖扩展文件夹内的一个文件。路径限制在该文件夹内。';

  @override
  String get command_plugins_read_desc => '读取扩展文件夹中的一个文件。';

  @override
  String get command_plugins_typings_desc =>
      '根据实时命令注册表重新生成 fancad.d.ts，使编辑器和模型看到真实 API。';

  @override
  String get command_plugins_edit_desc => '在内置编辑器中打开扩展文件，以便查看或修改 AI 编写循环写下的内容。';

  @override
  String get command_plugins_eval_desc =>
      '在扩展作用域中运行 JavaScript 表达式。用于调试；扩展能做的它都能做。';

  @override
  String command_step(String verb, String step) {
    return '$verb  $step';
  }

  @override
  String get prompt_specify_first_point => '指定第一点:';

  @override
  String get prompt_specify_next_point_esc => '指定下一点（按 Escape 结束）:';

  @override
  String get prompt_specify_second_point => '指定第二点:';

  @override
  String get prompt_specify_second_point_esc => '指定第二点（按 Escape 结束）:';

  @override
  String get prompt_specify_base_point => '指定基点:';

  @override
  String get prompt_select_objects => '选择对象:';

  @override
  String get prompt_specify_center => '指定中心:';

  @override
  String get prompt_specify_center_point => '指定圆心:';

  @override
  String get prompt_specify_radius => '指定半径:';

  @override
  String get prompt_specify_first_corner => '指定第一个角点:';

  @override
  String get prompt_specify_opposite_corner => '指定对角点:';

  @override
  String get prompt_specify_insertion_point => '指定插入点:';

  @override
  String get prompt_specify_next_insertion_esc => '指定下一插入点（按 Escape 结束）:';

  @override
  String get prompt_specify_height => '指定高度:';

  @override
  String get prompt_specify_start_point => '指定起点:';

  @override
  String get prompt_specify_through_point => '指定通过点:';

  @override
  String get prompt_specify_end_point => '指定端点:';

  @override
  String get prompt_specify_a_point => '指定一点:';

  @override
  String get prompt_specify_a_location => '指定位置:';

  @override
  String get prompt_specify_point => '指定点:';

  @override
  String get prompt_specify_vertex => '指定顶点:';

  @override
  String get prompt_specify_dim_line => '指定尺寸线位置:';

  @override
  String get prompt_specify_first_ext_origin => '指定第一条尺寸界线原点:';

  @override
  String get prompt_specify_second_ext_origin => '指定第二条尺寸界线原点:';

  @override
  String get prompt_specify_next_ext_origin => '指定下一条尺寸界线原点:';

  @override
  String get prompt_specify_second_ext_origin_alt => '指定第二条尺寸界线原点:';

  @override
  String get prompt_specify_dim_arc => '指定尺寸弧位置:';

  @override
  String get prompt_specify_rotation_angle => '指定旋转角度:';

  @override
  String get prompt_specify_new_height => '指定新高度:';

  @override
  String get prompt_specify_width_factor => '指定宽度因子:';

  @override
  String get prompt_specify_oblique => '指定倾斜角:';

  @override
  String get prompt_specify_column_width => '指定列宽:';

  @override
  String get prompt_specify_attachment_point => '指定附着点:';

  @override
  String get prompt_specify_scale_factor => '指定比例因子（或拾取距离）:';

  @override
  String get prompt_specify_offset_distance => '指定偏移距离:';

  @override
  String get prompt_specify_offset_side => '指定要偏移的一侧上的点:';

  @override
  String get prompt_specify_fillet_radius => '指定圆角半径:';

  @override
  String get prompt_specify_inside_diameter => '指定内径:';

  @override
  String get prompt_specify_outside_diameter => '指定外径:';

  @override
  String get prompt_specify_center_of_donut => '指定圆环中心:';

  @override
  String get prompt_specify_total_length => '指定总长:';

  @override
  String get prompt_specify_segment_length => '指定分段长度:';

  @override
  String get prompt_specify_stretch_point => '指定拉伸点:';

  @override
  String get prompt_idle_select => '选择对象或指定命令:';

  @override
  String get prompt_enter_layer_name => '输入图层名:';

  @override
  String get prompt_enter_a_layer_name => '输入图层名:';

  @override
  String get prompt_extension_id => '扩展 id:';

  @override
  String get prompt_enter_block_name => '输入块名:';

  @override
  String get prompt_enter_text => '输入文字:';

  @override
  String get prompt_select_closed_objects => '选择闭合对象:';

  @override
  String get prompt_select_viewport => '选择视口:';

  @override
  String get prompt_selected_viewport => '已选择视口';

  @override
  String get prompt_enter_colour => '输入颜色（1-255、#rrggbb 或 ByLayer）:';

  @override
  String get prompt_javascript => 'JavaScript:';

  @override
  String get prompt_svg_path => 'SVG 路径:';

  @override
  String get prompt_pdf_path => 'PDF 路径:';

  @override
  String get prompt_layout_name => '布局名:';

  @override
  String get prompt_layout_to_copy => '要复制的布局:';

  @override
  String get prompt_layout_to_delete => '要删除的布局:';

  @override
  String get prompt_layout_to_move => '要移动的布局:';

  @override
  String get prompt_layout_to_rename => '要重命名的布局:';

  @override
  String get prompt_drawing_to_attach => '要附着的图形:';

  @override
  String get prompt_file_to_write => '要写入的文件:';

  @override
  String get prompt_file_to_read => '要读取的文件:';

  @override
  String get prompt_select_objects_to_erase => '选择要删除的对象:';

  @override
  String get prompt_select_objects_to_array => '选择要阵列的对象:';

  @override
  String get prompt_select_objects_to_align => '选择要对齐的对象:';

  @override
  String get prompt_select_objects_to_rotate => '选择要旋转的对象:';

  @override
  String get prompt_select_objects_to_scale => '选择要缩放的对象:';

  @override
  String get prompt_select_objects_to_mirror => '选择要镜像的对象:';

  @override
  String get prompt_select_objects_to_offset => '选择要偏移的对象:';

  @override
  String get prompt_select_objects_to_explode => '选择要分解的对象:';

  @override
  String get prompt_select_objects_to_hide => '选择要隐藏的对象:';

  @override
  String get prompt_select_objects_keep_visible => '选择要保持可见的对象:';

  @override
  String get prompt_select_objects_recolour => '选择要重新着色的对象:';

  @override
  String get prompt_select_objects_change_layer => '选择要移到另一图层的对象:';

  @override
  String get prompt_select_text_objects => '选择文字对象:';

  @override
  String get prompt_textobject_options => '指定文字、高度、颜色、对正、旋转、样式、列宽、宽度因子或倾斜:';

  @override
  String prompt_place_n_points(int count) {
    return '放置 $count 个点？';
  }

  @override
  String prompt_specify_first_kind_point(String kind) {
    return '指定第一个$kind点:';
  }

  @override
  String prompt_specify_next_kind_point_esc(String kind) {
    return '指定下一个$kind点（按 Escape 结束）:';
  }

  @override
  String prompt_selected_object(String entity, String layer) {
    return '已选择 $entity，图层 $layer';
  }

  @override
  String prompt_objects_selected(int count) {
    return '已选择 $count 个对象';
  }

  @override
  String prompt_selection_found(String message, int count) {
    return '$message（已找到 $count 个，按 Enter 确认）';
  }

  @override
  String get prompt_enter_annotation_none => '输入注释文字 <无>:';

  @override
  String get prompt_enter_attribute_tag => '输入属性标签:';

  @override
  String get prompt_enter_block_name_to_change => '输入要更改的块名:';

  @override
  String get prompt_enter_default_value => '输入默认值:';

  @override
  String get prompt_enter_dimension_text => '输入标注文字（<> = 测量值）:';

  @override
  String get prompt_enter_justification =>
      '输入对正 [Left/Center/Right/TL/TC/TR/ML/MC/MR/BL/BC/BR]:';

  @override
  String get prompt_enter_layer_names => '输入图层名:';

  @override
  String get prompt_enter_spline_method => '输入方式 [Control/Fit]:';

  @override
  String get prompt_enter_linetype_name =>
      '输入名称（DASHED、HIDDEN、CENTER、ByLayer）:';

  @override
  String get prompt_enter_new_block_name => '输入新块名:';

  @override
  String get prompt_enter_new_text => '输入新文字:';

  @override
  String get prompt_enter_columns => '输入列数:';

  @override
  String get prompt_enter_items => '输入项目数:';

  @override
  String get prompt_enter_rows => '输入行数:';

  @override
  String get prompt_enter_sides => '输入边数:';

  @override
  String get prompt_enter_object_type => '输入对象类型（LINE、CIRCLE、INSERT、…）:';

  @override
  String get prompt_enter_attribute_prompt => '输入提示:';

  @override
  String get prompt_enter_fill_angle => '输入填充角度:';

  @override
  String get prompt_enter_column_spacing => '输入列间距:';

  @override
  String get prompt_enter_segments => '输入分段数:';

  @override
  String get prompt_enter_row_spacing => '输入行间距:';

  @override
  String get prompt_enter_lineweight => '输入线宽（0.25 mm、25、ByLayer）:';

  @override
  String get prompt_fillet_vertex_all => '圆角 [Vertex/All]:';

  @override
  String get prompt_chamfer_vertex_all => '倒角 [Vertex/All]:';

  @override
  String get prompt_select_block_reference => '选择块参照:';

  @override
  String get prompt_select_line_pline_arc => '选择直线、多段线或圆弧:';

  @override
  String get prompt_select_linear_aligned_dim => '选择线性或对齐标注:';

  @override
  String get prompt_select_arc_or_circle => '选择圆弧或圆:';

  @override
  String get prompt_select_arc_or_first_line => '选择圆弧或第一条直线:';

  @override
  String get prompt_select_boundary_edges => '选择边界边:';

  @override
  String get prompt_select_circles_or_arcs => '选择圆或圆弧:';

  @override
  String get prompt_select_closed_boundaries => '选择闭合边界:';

  @override
  String get prompt_select_cutting_edges => '选择剪切边:';

  @override
  String get prompt_select_destination_objects => '选择目标对象:';

  @override
  String get prompt_select_dimensions => '选择标注:';

  @override
  String get prompt_select_first_line_circle_arc => '选择第一条直线、圆或圆弧:';

  @override
  String get prompt_select_first_object => '选择第一个对象:';

  @override
  String get prompt_select_first_tangent => '选择第一个相切对象:';

  @override
  String get prompt_select_hatch_objects => '选择填充对象:';

  @override
  String get prompt_select_lines_or_plines => '选择直线或多段线:';

  @override
  String get prompt_select_lines_to_convert => '选择要转换的直线:';

  @override
  String get prompt_select_join_objects => '选择要合并的直线、圆弧或多段线:';

  @override
  String get prompt_select_object_to_break => '选择要打断的对象:';

  @override
  String get prompt_select_object_to_divide => '选择要等分的对象:';

  @override
  String get prompt_select_object_to_measure => '选择要定距等分的对象:';

  @override
  String get prompt_select_plines_to_close => '选择要闭合的多段线:';

  @override
  String get prompt_select_plines_to_open => '选择要打开的多段线:';

  @override
  String get prompt_select_plines_width => '选择要设置宽度的多段线:';

  @override
  String get prompt_select_second_line_circle_arc => '选择第二条直线、圆或圆弧:';

  @override
  String get prompt_select_second_line => '选择第二条直线:';

  @override
  String get prompt_select_second_tangent => '选择第二个相切对象:';

  @override
  String get prompt_select_source_object => '选择源对象:';

  @override
  String get prompt_select_text_mtext_dim => '选择文字、多行文字或标注:';

  @override
  String get prompt_specify_nearer_end => '指定更靠近要更改一端的点:';

  @override
  String get prompt_specify_first_ray_point => '指定第一条射线上的点:';

  @override
  String get prompt_specify_second_ray_point => '指定第二条射线上的点:';

  @override
  String get prompt_specify_second_point_on_arc => '指定圆弧上的第二点:';

  @override
  String get prompt_specify_vertex_to_bevel => '指定要倒角的顶点:';

  @override
  String get prompt_specify_vertex_to_round => '指定要圆角的顶点:';

  @override
  String get prompt_specify_column_distance => '指定列间距:';

  @override
  String get prompt_specify_row_distance => '指定行间距:';

  @override
  String get prompt_specify_other_axis_distance => '指定到另一轴的距离:';

  @override
  String get prompt_specify_axis_endpoint => '指定轴端点:';

  @override
  String get prompt_specify_first_break => '指定第一个打断点:';

  @override
  String get prompt_specify_first_chamfer => '指定第一个倒角距离:';

  @override
  String get prompt_specify_crossing_first_corner => '指定跨越窗口的第一个角点:';

  @override
  String get prompt_specify_first_dest => '指定第一个目标点:';

  @override
  String get prompt_specify_first_diameter_end => '指定直径的第一端:';

  @override
  String get prompt_specify_first_leader_point => '指定引线第一点:';

  @override
  String get prompt_specify_mirror_first => '指定镜像线第一点:';

  @override
  String get prompt_specify_first_on_circle => '指定圆上第一点:';

  @override
  String get prompt_specify_first_source => '指定第一个源点:';

  @override
  String get prompt_specify_insertion_base => '指定插入基点:';

  @override
  String get prompt_hatch_internal_or_select => '指定内部点或 [Select]:';

  @override
  String get prompt_specify_dim_text_location => '指定标注文字的新位置:';

  @override
  String get prompt_specify_polyline_width => '指定所有线段的新宽度:';

  @override
  String get prompt_specify_second_break_esc => '指定第二个打断点（按 Escape 仅拆分）:';

  @override
  String get prompt_specify_second_chamfer => '指定第二个倒角距离:';

  @override
  String get prompt_specify_second_dest => '指定第二个目标点:';

  @override
  String get prompt_specify_second_diameter_end => '指定直径的第二端:';

  @override
  String get prompt_specify_mirror_second => '指定镜像线第二点:';

  @override
  String get prompt_specify_second_on_circle => '指定圆上第二点:';

  @override
  String get prompt_specify_second_source_or_enter => '指定第二个源点或按 Enter:';

  @override
  String get prompt_specify_third_on_circle => '指定圆上第三点:';

  @override
  String prompt_enter_units(String current) {
    return '输入插入单位 <$current>:';
  }

  @override
  String get prompt_enter_text_style_name => '输入文字样式名:';

  @override
  String get prompt_enter_layer_to_delete => '输入要删除的图层:';

  @override
  String get prompt_enter_layer_to_isolate => '输入要隔离的图层:';

  @override
  String get prompt_enter_linetype => '输入线型（DASHED、ByLayer、…）:';

  @override
  String get prompt_enter_a_lineweight => '输入线宽（0.25 mm、25、ByLayer）:';

  @override
  String get prompt_select_object_to_trim => '选择要修剪的对象（按 Escape 结束）:';

  @override
  String get prompt_select_object_to_extend => '选择要延伸的对象（按 Escape 结束）:';

  @override
  String get prompt_scale_objects_align => '根据对齐点缩放对象？';

  @override
  String get prompt_sheet_width => '图纸宽度 (mm):';

  @override
  String get prompt_sheet_height => '图纸高度 (mm):';

  @override
  String get prompt_viewport_scale => '视口比例（模型 / 图纸）:';

  @override
  String get prompt_new_layout_name => '新布局名称:';

  @override
  String get prompt_open_recent => '打开最近的文件:';

  @override
  String get end => '终点';

  @override
  String get min => '最小';

  @override
  String get max => '最大';

  @override
  String get objects_in_drawing_one => '此图纸有 1 个对象。';

  @override
  String get use => '使用';

  @override
  String objects_in_drawing_many(int count) {
    return '此图纸有 $count 个对象。';
  }
}

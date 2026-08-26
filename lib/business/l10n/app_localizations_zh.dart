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
  String get appearance_dark_tooltip => '外观 — 深色。可切换浅色或深色';

  @override
  String get appearance_light_tooltip => '外观 — 浅色。可切换浅色或深色';

  @override
  String get settings => '设置';

  @override
  String get settings_tooltip => '设置。主题、语言和助手';

  @override
  String get settings_tab_general => '常规';

  @override
  String get settings_tab_assistant => '助手';

  @override
  String get settings_appearance => '外观';

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
  String get empty_drawing_title => '此图纸为空';

  @override
  String get empty_drawing_hint => '从工具栏开始命令，输入别名如 L 或 C，或选择下方命令。';

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
  String get assistant_profiles => '配置';

  @override
  String get add_assistant_profile => '添加配置';

  @override
  String get remove_assistant_profile => '删除配置';

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
  String get ask_assistant => '询问助手  Enter 发送';

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
  String get command_edit_erase => '删除';

  @override
  String get command_edit_overkill => '删除重复';

  @override
  String get command_edit_move => '移动';

  @override
  String get command_edit_copy => '复制';

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

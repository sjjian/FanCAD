#include "include/desktop_open_files/desktop_open_files_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <cstring>

#define OPEN_FILES_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), open_files_plugin_get_type(), \
                              OpenFilesPlugin))

struct _OpenFilesPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(OpenFilesPlugin, open_files_plugin, G_TYPE_OBJECT)

static void open_files_plugin_handle_method_call(OpenFilesPlugin* self,
                                                 FlMethodCall* method_call) {
  (void)self;
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "listen") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(list));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  OpenFilesPlugin* plugin = OPEN_FILES_PLUGIN(user_data);
  open_files_plugin_handle_method_call(plugin, method_call);
}

static void open_files_plugin_dispose(GObject* object) {
  OpenFilesPlugin* self = OPEN_FILES_PLUGIN(object);
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(open_files_plugin_parent_class)->dispose(object);
}

static void open_files_plugin_class_init(OpenFilesPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = open_files_plugin_dispose;
}

static void open_files_plugin_init(OpenFilesPlugin* self) {}

void open_files_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  OpenFilesPlugin* plugin = OPEN_FILES_PLUGIN(
      g_object_new(open_files_plugin_get_type(), nullptr));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "desktop_open_files",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}

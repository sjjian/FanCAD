#include "include/desktop_open_files/desktop_open_files_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace {

class OpenFilesPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "desktop_open_files",
            &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<OpenFilesPlugin>();
    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });
    registrar->AddPlugin(std::move(plugin));
  }

  OpenFilesPlugin() = default;
  virtual ~OpenFilesPlugin() = default;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name() != "listen") {
      result->NotImplemented();
      return;
    }
    // Explorer Open With starts a new process; those paths arrive as argv.
    result->Success(flutter::EncodableValue(flutter::EncodableList{}));
  }
};

}  // namespace

void OpenFilesPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  OpenFilesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

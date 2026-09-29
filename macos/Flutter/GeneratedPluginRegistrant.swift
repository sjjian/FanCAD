//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import desktop_open_files
import device_info_plus
import file_selector_macos
import irondash_engine_context
import quickjs_engine
import screen_retriever_macos
import super_native_extensions
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  OpenFilesPlugin.register(with: registry.registrar(forPlugin: "OpenFilesPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  IrondashEngineContextPlugin.register(with: registry.registrar(forPlugin: "IrondashEngineContextPlugin"))
  QuickjsEnginePlugin.register(with: registry.registrar(forPlugin: "QuickjsEnginePlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SuperNativeExtensionsPlugin.register(with: registry.registrar(forPlugin: "SuperNativeExtensionsPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}

Pod::Spec.new do |s|
  s.name             = 'desktop_open_files'
  s.version          = '0.1.0'
  s.summary          = 'macOS host for desktop file-open events.'
  s.description      = 'Queues Finder / Dock / open -a files until Dart listens.'
  s.homepage         = 'https://github.com/sunjian/FanCAD'
  s.license          = { :type => 'MIT' }
  s.author           = { 'FanCAD' => 'fancad' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end

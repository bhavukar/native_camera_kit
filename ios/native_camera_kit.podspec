#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_camera_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_camera_kit'
  s.version          = '0.0.2'
  s.summary          = 'High-performance Flutter camera plugin with direct low-level sensor access.'
  s.description      = <<-DESC
High-performance Flutter camera plugin with direct low-level sensor access, manual ISO, shutter speed, focus, and raw frame streaming for Android & iOS.
                       DESC
  s.homepage         = 'https://github.com/bhavukarora/native_camera_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bhavuk Arora' => 'bhavukarora@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'native_camera_kit/Sources/native_camera_kit/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

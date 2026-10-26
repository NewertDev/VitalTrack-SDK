#
# Bundles the prebuilt core as a dynamic framework
# (Frameworks/VitalTrackCore.xcframework, built on a Mac with
# tools/build_ios.sh). Nothing is compiled from source here.
#
Pod::Spec.new do |s|
  s.name             = 'vitaltrack_eeg'
  s.version          = '0.1.1'
  s.summary          = 'VitalTrack EEG SDK'
  s.description      = 'Connect to VitalTrack EEG boards and receive clean EEG.'
  s.homepage         = 'https://newert.co.kr'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Newert' => 'joseph@newert.co.kr' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.vendored_frameworks = 'Frameworks/VitalTrackCore.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end

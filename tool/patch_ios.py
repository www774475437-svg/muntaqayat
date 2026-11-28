"""Runs on GitHub after `flutter create --platforms ios`: Arabic name, the texts iOS shows
when asking for the microphone and photos, Google sign-in's return address, «الدخول بحساب Apple»,
the lowest iOS version, and (when the signing files are there) the App Store signing."""
import os
import plistlib
import re
from pathlib import Path

TEAM = "373H2CNKHF"
BUNDLE = "com.muntaqayat.muntaqayat"
PROFILE = "Muntaqayat App Store"
IOS_CLIENT = "581548975960-c9fut35d4qqov4qqe4pgs3mad1h8qam3"
SIGN = os.environ.get("SIGN") == "1"

info = Path("ios/Runner/Info.plist")
with info.open("rb") as f:
    p = plistlib.load(f)
p["CFBundleDisplayName"] = "منتقيات الشعر"
p["CFBundleName"] = "منتقيات الشعر"
p["CFBundleDevelopmentRegion"] = "ar"
p["CFBundleLocalizations"] = ["ar"]
p["ITSAppUsesNonExemptEncryption"] = False
p["NSMicrophoneUsageDescription"] = "يُستعمل الميكروفون للبحث بالصوت عن بيت من الشعر، ولتسميع ما تحفظه."
p["NSSpeechRecognitionUsageDescription"] = "يُحوَّل صوتك إلى نص للبحث عن البيت الذي تنطق به."
p["NSPhotoLibraryUsageDescription"] = "تختار صورة من صورك لتكون خلفية صفحتك الشخصية."
p["GIDClientID"] = IOS_CLIENT + ".apps.googleusercontent.com"
p["CFBundleURLTypes"] = [{"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": ["com.googleusercontent.apps." + IOS_CLIENT]}]
p["UISupportedInterfaceOrientations"] = ["UIInterfaceOrientationPortrait"]
p["UIRequiresFullScreen"] = True
with info.open("wb") as f:
    plistlib.dump(p, f)

Path("ios/Runner/Runner.entitlements").write_bytes(plistlib.dumps({"com.apple.developer.applesignin": ["Default"]}))

proj = Path("ios/Runner.xcodeproj/project.pbxproj")
s = proj.read_text(encoding="utf-8")
s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", s)


def block(m):
    b = m.group(1)
    if f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};" not in b:
        return m.group(0)
    drop = ("CODE_SIGN_ENTITLEMENTS", "DEVELOPMENT_TEAM", "CODE_SIGN_STYLE", "PROVISIONING_PROFILE_SPECIFIER", "CODE_SIGN_IDENTITY", '"CODE_SIGN_IDENTITY')
    lines = [l for l in b.split("\n") if not l.strip().startswith(drop)]
    add = ["CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;", f"DEVELOPMENT_TEAM = {TEAM};", "TARGETED_DEVICE_FAMILY = 1;"]
    if SIGN:
        add += ["CODE_SIGN_STYLE = Manual;", '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";', f'PROVISIONING_PROFILE_SPECIFIER = "{PROFILE}";']
    lines = [l for l in lines if not l.strip().startswith("TARGETED_DEVICE_FAMILY")]
    return "buildSettings = {" + "\n".join(lines) + "\n" + "\n".join("\t\t\t\t" + a for a in add) + "\n\t\t\t};"


s = re.sub(r"buildSettings = \{(.*?)\n\t\t\t\};", block, s, flags=re.S)
proj.write_text(s, encoding="utf-8")

fw = Path("ios/Flutter/AppFrameworkInfo.plist")
if fw.exists():
    t = fw.read_text(encoding="utf-8")
    t = re.sub(r"(<key>MinimumOSVersion</key>\s*<string>)[0-9.]+(</string>)", r"\g<1>15.0\2", t)
    fw.write_text(t, encoding="utf-8")

Path("ios/Podfile").write_text('''platform :ios, '15.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
''', encoding="utf-8")

Path("ios/ExportOptions.plist").write_bytes(plistlib.dumps({
    "method": "app-store-connect",
    "teamID": TEAM,
    "signingStyle": "manual",
    "provisioningProfiles": {BUNDLE: PROFILE},
    "uploadSymbols": True,
}))
print("iOS patched", "(signed)" if SIGN else "(unsigned)")

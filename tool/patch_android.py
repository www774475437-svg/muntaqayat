"""Runs on GitHub after `flutter create`: Arabic app name, permissions,
notification receivers, desugaring, the «بيت اليوم» home-screen widget,
launch colour and the permanent signing key."""
import glob
import re
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="منتقيات الشعر"', m, count=1)
for p in ["android.permission.INTERNET", "android.permission.POST_NOTIFICATIONS",
          "android.permission.RECEIVE_BOOT_COMPLETED", "android.permission.RECORD_AUDIO"]:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)

# Voice search needs to see the phone's speech service.
if "android.speech.RecognitionService" not in m:
    q = '<intent><action android:name="android.speech.RecognitionService"/></intent>'
    if "<queries>" in m:
        m = m.replace("<queries>", "<queries>" + q, 1)
    else:
        m = m.replace("<application", "<queries>" + q + "</queries>\n    <application", 1)

extra = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:name=".VerseWidgetProvider" android:exported="true" android:label="بيت اليوم">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/verse_widget_info" />
        </receiver>
"""
if "ScheduledNotificationReceiver" not in m:
    m = m.replace("</application>", extra + "    </application>", 1)
manifest.write_text(m, encoding="utf-8")
print("Manifest patched")

# --- the home-screen widget ----------------------------------------------
res = Path("android/app/src/main/res")
(res / "xml").mkdir(parents=True, exist_ok=True)
(res / "layout").mkdir(parents=True, exist_ok=True)
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "xml/verse_widget_info.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/verse_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
''', encoding="utf-8")
(res / "drawable/verse_widget_bg.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#F7F4EE" />
    <stroke android:width="1dp" android:color="#E0D9CC" />
    <corners android:radius="24dp" />
</shape>
''', encoding="utf-8")
(res / "layout/verse_widget.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="14dp"
    android:layoutDirection="rtl"
    android:background="@drawable/verse_widget_bg">
    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="بيت اليوم"
        android:textColor="#8C4A2F"
        android:textSize="13sp" />
    <TextView
        android:id="@+id/widget_verse"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:gravity="center"
        android:lineSpacingMultiplier="1.25"
        android:text="افتح التطبيق لترى بيت اليوم"
        android:textColor="#1E1B16"
        android:textSize="17sp" />
    <TextView
        android:id="@+id/widget_poet"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:text="منتقيات الشعر"
        android:textColor="#7B746A"
        android:textSize="13sp" />
</LinearLayout>
''', encoding="utf-8")
for f in glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
    pkg = re.search(r"^package\s+(\S+)", Path(f).read_text(encoding="utf-8"), re.M).group(1)
    Path(f).with_name("VerseWidgetProvider.kt").write_text(f"""package {pkg}

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class VerseWidgetProvider : HomeWidgetProvider() {{
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {{
        appWidgetIds.forEach {{ id ->
            val views = RemoteViews(context.packageName, R.layout.verse_widget).apply {{
                setTextViewText(R.id.widget_verse, widgetData.getString("verse", "افتح التطبيق لترى بيت اليوم"))
                setTextViewText(R.id.widget_poet, widgetData.getString("poet", "منتقيات الشعر"))
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }}
            appWidgetManager.updateAppWidget(id, views)
        }}
    }}
}}
""", encoding="utf-8")
    print("Widget provider written in", pkg)

# --- build.gradle.kts: desugaring and the permanent signing key ---------
kts = Path("android/app/build.gradle.kts")
g = kts.read_text(encoding="utf-8")
if "isCoreLibraryDesugaringEnabled" not in g:
    g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
if "desugar_jdk_libs" not in g:
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
if "keyProps" not in g:
    g = "import java.util.Properties\n" + g
    g = g.replace("android {", '''val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {''', 1)
    g = g.replace("    buildTypes {", '''    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }

    buildTypes {''', 1)
    g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                  'signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', 1)
kts.write_text(g, encoding="utf-8")
print("build.gradle.kts patched")

for d in ["drawable", "drawable-v21"]:
    lb = Path(f"android/app/src/main/res/{d}/launch_background.xml")
    if lb.exists():
        lb.write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><color android:color="#F7F4EE" /></item>
</layer-list>
''', encoding="utf-8")
print("Launch background set")

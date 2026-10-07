import sys, os
os.environ["QT_QPA_PLATFORM"] = "offscreen"
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent

app = QGuiApplication(sys.argv)
engine = QQmlEngine()

engine.rootContext().setContextProperty("Theme", {
    "spacingXS": 4, "spacingS": 8, "spacingM": 12, "spacingL": 16,
    "fontSizeSmall": 12, "fontSizeMedium": 14,
    "primary": "#123456", "surface": "#ffffff", "surfaceText": "#000000",
    "surfaceVariantText": "#888888", "surfaceContainerHighest": "#222222",
    "surfaceContainerHigh": "#333333", "error": "#ff0000", "outline": "#555555",
    "cornerRadius": 12, "isLightMode": False,
    "withAlpha": lambda c, a: c
})
engine.rootContext().setContextProperty("PluginService", {
    "loadPluginData": lambda p, k, d: d,
    "savePluginData": lambda p, k, v: None,
    "setGlobalVar": lambda p, k, v: None
})

mocks = """
import QtQuick
import QtQuick.Layouts

Item {
    id: dummyRoot
    component PluginSettings: Item { property string pluginId; default property list<QtObject> content }
    component DankIcon: Item { property string name; property int size; property color color }
    component DankRipple: Item { property real cornerRadius; property color rippleColor; function trigger(x,y){} }
    component DankTextField: Item { property string placeholderText; property string text; signal accepted }
    component DankToggle: Item { property bool checked; signal toggled(bool checked) }
    component StyledText: Text {}
"""

with open("DnsSwitcherSettings.qml") as f:
    code = f.read()

lines = code.split("\n")
clean_lines = []
for line in lines:
    if line.startswith("import "):
        continue
    clean_lines.append(line)

mocked_code = mocks + "\n" + "\n".join(clean_lines) + "\n}"

comp = QQmlComponent(engine)
comp.setData(mocked_code.encode("utf-8"), "")
print("Status:", comp.status())
if comp.isError():
    for e in comp.errors():
        print("ERROR:", e.toString())
else:
    obj = comp.create()
    print("Instance created successfully!", obj)

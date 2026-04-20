import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "dnsTile"

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
            PluginService.setGlobalVar(root.pluginId, key, val);
        }

        // --- General Settings ---
        Rectangle {
            id: generalRect
            width: parent.width
            height: generalGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: generalGroup
                width: parent.width - Theme.spacingM * 2
                anchors.centerIn: parent
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "settings_ethernet"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Network Interface"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "The plugin automatically detects the active connection. No manual configuration usually needed."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }

        // --- Custom DNS Management (Future Proofing) ---
        Rectangle {
            id: customDnsRect
            width: parent.width
            height: customDnsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: customDnsGroup
                width: parent.width - Theme.spacingM * 2
                anchors.centerIn: parent
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    StyledText { text: "Custom DNS Overrides"; font.weight: Font.Bold; color: Theme.surfaceText }
                    StyledText { text: "Manually specify additional DNS providers in the widget for quick access."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                }

                // Placeholder for future dynamic list management
                StyledText { 
                    text: "Advanced customization coming soon."
                    font.pixelSize: Theme.fontSizeSmall
                    font.italic: true
                    color: Theme.primary
                    opacity: 0.7
                }
            }
        }
    }
}

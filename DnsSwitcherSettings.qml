import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "dnsSwitcher"

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

        // --- State ---
        property var hiddenProviders: []
        property var customProviders: []

        function loadAll() {
            let hidden = loadValue("hiddenProviders", "[]");
            try { hiddenProviders = JSON.parse(hidden); } catch(e) { hiddenProviders = []; }
            
            let custom = loadValue("customProviders", "[]");
            try { customProviders = JSON.parse(custom); } catch(e) { customProviders = []; }
        }

        function saveHidden() {
            saveValue("hiddenProviders", JSON.stringify(hiddenProviders));
        }

        function saveCustom() {
            saveValue("customProviders", JSON.stringify(customProviders));
        }

        Component.onCompleted: loadAll()

        // --- General Settings Section ---
        Rectangle {
            width: parent.width
            height: generalCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: generalCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    DankIcon { 
                        name: "public"
                        size: 22
                        opacity: 0.8
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacingXS
                        StyledText { text: "Show IP Address"; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Display your public IP address and location in the widget."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    }
                    
                    DankToggle {
                        id: showIpSwitch
                        Layout.alignment: Qt.AlignVCenter
                        Component.onCompleted: {
                            checked = mainSettingsCol.loadValue("showIpAddress", "false") === "true";
                        }
                        onToggled: function(newChecked) {
                            checked = newChecked;
                            mainSettingsCol.saveValue("showIpAddress", newChecked ? "true" : "false");
                        }
                    }
                }
            }
        }

        // --- Provider Visibility Section ---
        Rectangle {
            width: parent.width
            height: visibilityCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: visibilityCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    DankIcon { name: "visibility"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        spacing: Theme.spacingXS
                        StyledText { text: "Provider Visibility"; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Choose which DNS providers appear in the widget."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    
                    Repeater {
                        model: ["System Default", "Google", "Cloudflare", "OpenDNS", "AdGuard", "Quad9"]
                        delegate: Rectangle {
                            width: Math.max(0, (visibilityCol.width - Theme.spacingS) / 2 - 1)
                            height: 40
                            radius: 8
                            color: isHidden ? Theme.surfaceContainerHighest : Theme.primaryContainer
                            border.color: isHidden ? Theme.outline : Theme.primary
                            border.width: 1
                            
                            property bool isHidden: mainSettingsCol.hiddenProviders.indexOf(modelData) !== -1

                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacingS
                                DankIcon { 
                                    name: modelData === "System Default" ? "dns" : "language"
                                    size: 16; color: isHidden ? Theme.surfaceVariantText : Theme.primary 
                                }
                                StyledText { text: modelData; Layout.fillWidth: true; color: isHidden ? Theme.surfaceVariantText : Theme.primary; font.pixelSize: Theme.fontSizeSmall }
                                DankIcon { 
                                    name: isHidden ? "visibility_off" : "visibility"
                                    size: 16; color: isHidden ? Theme.surfaceVariantText : Theme.primary 
                                }
                            }

                            Rectangle {
                                anchors.fill: parent; radius: 8
                                color: Theme.surfaceText
                                opacity: maVisibility.containsMouse ? 0.05 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: maVisibility
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    let list = Array.from(mainSettingsCol.hiddenProviders);
                                    let idx = list.indexOf(modelData);
                                    if (idx === -1) list.push(modelData);
                                    else list.splice(idx, 1);
                                    mainSettingsCol.hiddenProviders = list;
                                    mainSettingsCol.saveHidden();
                                }
                                onPressed: (m) => ripVisibility.trigger(m.x, m.y)
                            }
                            
                            DankRipple { id: ripVisibility; anchors.fill: parent; cornerRadius: 8; rippleColor: Theme.surfaceText }
                        }
                    }
                }
            }
        }

        // --- Custom Providers Section ---
        Rectangle {
            width: parent.width
            height: customCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: customCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    DankIcon { name: "add_circle"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        spacing: Theme.spacingXS
                        StyledText { text: "Custom Presets"; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Add your own DNS servers to the quick list."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }

                // Add Form
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS
                        DankTextField { id: newName; Layout.fillWidth: true; placeholderText: "Name (e.g. My DNS)" }
                        DankTextField { id: newIcon; width: 100; placeholderText: "Icon (dns)" }
                    }
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS
                        DankTextField { id: newIp; Layout.fillWidth: true; placeholderText: "IPs (8.8.8.8, 8.8.4.4)" }
                        Rectangle {
                            width: 32; height: 32; radius: 8
                            color: (newName.text && newIp.text) ? Theme.primary : Theme.surfaceContainerHighest
                            opacity: (newName.text && newIp.text) ? 1.0 : 0.5
                            DankIcon { name: "add"; size: 18; color: Theme.surface; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent
                                enabled: newName.text && newIp.text
                                onClicked: {
                                    let list = Array.from(mainSettingsCol.customProviders);
                                    list.push({
                                        name: newName.text,
                                        ip: newIp.text,
                                        icon: newIcon.text || "dns"
                                    });
                                    mainSettingsCol.customProviders = list;
                                    mainSettingsCol.saveCustom();
                                    newName.text = ""; newIp.text = ""; newIcon.text = "";
                                }
                            }
                        }
                    }
                }

                // List
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    Repeater {
                        model: mainSettingsCol.customProviders
                        delegate: Rectangle {
                            width: parent.width; height: 44; radius: 8
                            color: Theme.surfaceContainerHigh
                            border.color: Theme.outline
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacingS
                                DankIcon { name: modelData.icon || "dns"; size: 18; color: Theme.primary }
                                Column {
                                    Layout.fillWidth: true
                                    StyledText { text: modelData.name; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                    StyledText { text: modelData.ip; font.pixelSize: Theme.fontSizeSmall - 2; color: Theme.surfaceVariantText; elide: Text.ElideRight }
                                }
                                    Item { 
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        
                                        Rectangle {
                                            anchors.fill: parent; radius: 12
                                            color: Theme.error; opacity: maDelete.containsMouse ? 0.15 : 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }

                                        DankIcon { name: "delete"; size: 16; color: Theme.error; anchors.centerIn: parent }

                                        MouseArea {
                                            id: maDelete
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                let list = Array.from(mainSettingsCol.customProviders);
                                                list.splice(index, 1);
                                                mainSettingsCol.customProviders = list;
                                                mainSettingsCol.saveCustom();
                                            }
                                            onPressed: (m) => ripDelete.trigger(m.x, m.y)
                                        }
                                        DankRipple { id: ripDelete; anchors.fill: parent; cornerRadius: 12; rippleColor: Theme.error }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}

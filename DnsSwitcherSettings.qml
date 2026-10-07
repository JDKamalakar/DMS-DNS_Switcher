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

    readonly property real outerR: Theme.cornerRadius || 12
    readonly property real innerR: 4

    function loadValue(key, def) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }
        return def;
    }

    function saveValue(key, val) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.savePluginData) {
            PluginService.savePluginData(root.pluginId, key, val);
            if (PluginService.setGlobalVar) {
                PluginService.setGlobalVar(root.pluginId, key, val);
            }
        }
    }

    // --- State ---
    property var hiddenProviders: []
    property var customProviders: []
    property int customVersion: 0

    readonly property var customProvidersModel: {
        void(customVersion);
        return customProviders || [];
    }

    function loadAll() {
        let hidden = loadValue("hiddenProviders", "[]");
        try { 
            let parsedHidden = typeof hidden === "string" ? JSON.parse(hidden) : hidden;
            hiddenProviders = Array.isArray(parsedHidden) ? parsedHidden : [];
        } catch(e) { 
            hiddenProviders = []; 
        }
        
        let custom = loadValue("customProviders", "[]");
        try { 
            let parsedCustom = typeof custom === "string" ? JSON.parse(custom) : custom;
            customProviders = Array.isArray(parsedCustom) ? parsedCustom : [];
        } catch(e) { 
            customProviders = []; 
        }
        customVersion++;
    }

    function saveHidden(list) {
        let val = list !== undefined ? list : hiddenProviders;
        saveValue("hiddenProviders", JSON.stringify(val));
    }

    function saveCustom(list) {
        let val = list !== undefined ? list : customProviders;
        saveValue("customProviders", JSON.stringify(val));
        customVersion++;
    }

    function addCustomProvider(name, ip, icon) {
        let nameTrimmed = (name || "").trim();
        let ipTrimmed = (ip || "").trim();
        if (!nameTrimmed || !ipTrimmed) return false;

        let list = Array.isArray(customProviders) ? customProviders.slice() : [];
        list.push({
            name: nameTrimmed,
            ip: ipTrimmed,
            icon: (icon || "").trim() || "dns"
        });
        customProviders = list;
        saveCustom(list);
        return true;
    }

    function deleteCustomProvider(targetIndex) {
        if (!Array.isArray(customProviders) || targetIndex < 0 || targetIndex >= customProviders.length) return;
        let list = customProviders.slice();
        list.splice(targetIndex, 1);
        customProviders = list;
        saveCustom(list);
    }

    Component.onCompleted: loadAll()

    onPluginServiceChanged: {
        if (pluginService) {
            loadAll();
        }
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
    }

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        // --- General Settings Section ---
        Column {
            width: parent.width
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "tune"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "General Preferences"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // Segment 1: Show IP Address Toggle
                Rectangle {
                    width: parent.width
                    height: 56
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    topLeftRadius: root.outerR
                    topRightRadius: root.outerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showIpSwitch.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "public"
                                size: 18
                                color: showIpSwitch.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Show IP Address"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Display public IP address and geolocation card in the widget (via ipinfo.io)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; elide: Text.ElideRight }
                        }

                        DankToggle {
                            id: showIpSwitch
                            Layout.alignment: Qt.AlignVCenter
                            Component.onCompleted: {
                                checked = root.loadValue("showIpAddress", "false") === "true";
                            }
                            onToggled: function(newChecked) {
                                checked = newChecked;
                                root.saveValue("showIpAddress", newChecked ? "true" : "false");
                            }
                        }
                    }
                }

                // Segment 2: Animation on Auto-Refresh Toggle
                Rectangle {
                    width: parent.width
                    height: 56
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.outerR
                    bottomRightRadius: root.outerR

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showCheckAnim.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "auto_awesome_motion"
                                size: 18
                                color: showCheckAnim.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText {
                                text: "Animation on Auto-Refresh"
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Show indicator during background checks (manual refresh always animates)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        DankToggle {
                            id: showCheckAnim
                            Layout.alignment: Qt.AlignVCenter
                            Component.onCompleted: {
                                checked = root.loadValue("showCheckAnim", "false") === "true";
                            }
                            onToggled: function (newChecked) {
                                checked = newChecked;
                                root.saveValue("showCheckAnim", newChecked ? "true" : "false");
                            }
                        }
                    }
                }
            }
        }

        // --- Provider Visibility Section ---
        Column {
            width: parent.width
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "visibility"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Provider Visibility"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: visibilityInnerCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                Column {
                    id: visibilityInnerCol
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Choose which preset DNS providers appear in the quick list"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Flow {
                        id: visFlow
                        width: parent.width
                        spacing: Theme.spacingS

                        readonly property var defaultIcons: ({
                            "System Default": "cloud_off",
                            "Google": "assets/icons/google.svg",
                            "Cloudflare": "assets/icons/cloudflare.svg",
                            "OpenDNS": "assets/icons/opendns.svg",
                            "AdGuard": "assets/icons/adguard.svg",
                            "Quad9": "assets/icons/quad9.svg"
                        })
                        
                        Repeater {
                            model: ["System Default", "Google", "Cloudflare", "OpenDNS", "AdGuard", "Quad9"]
                            delegate: Rectangle {
                                id: providerPill
                                width: Math.max(0, (visFlow.width - Theme.spacingS) / 2 - 1)
                                height: 44
                                
                                property bool isTopRow: index < 2
                                property bool isBottomRow: index >= 4
                                property bool isLeftCol: index % 2 === 0
                                property bool isRightCol: index % 2 === 1

                                topLeftRadius: (isTopRow && isLeftCol) ? root.outerR : root.innerR
                                topRightRadius: (isTopRow && isRightCol) ? root.outerR : root.innerR
                                bottomLeftRadius: (isBottomRow && isLeftCol) ? root.outerR : root.innerR
                                bottomRightRadius: (isBottomRow && isRightCol) ? root.outerR : root.innerR

                                color: isHidden ? Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.4) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                border.color: isHidden ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                border.width: 1
                                scale: maVisibility.pressed ? 0.98 : (maVisibility.containsMouse ? 1.02 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                
                                property bool isHidden: root.hiddenProviders.indexOf(modelData) !== -1
                                property string iconSource: visFlow.defaultIcons[modelData] || "dns"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: Theme.spacingS

                                    Item {
                                        width: 18
                                        height: 18
                                        Layout.alignment: Qt.AlignVCenter

                                        DankIcon {
                                            name: providerPill.iconSource
                                            size: 18
                                            color: providerPill.isHidden ? Theme.surfaceVariantText : Theme.primary
                                            anchors.centerIn: parent
                                            visible: !providerPill.iconSource.includes("/")
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Image {
                                            anchors.fill: parent
                                            visible: providerPill.iconSource.includes("/")
                                            source: providerPill.iconSource.includes("/") ? Qt.resolvedUrl(!Theme.isLightMode && providerPill.iconSource.endsWith(".svg") ? providerPill.iconSource.replace(".svg", "_white.svg") : providerPill.iconSource) : ""
                                            sourceSize.width: 18
                                            sourceSize.height: 18
                                            opacity: providerPill.isHidden ? 0.4 : 1.0
                                            smooth: true
                                        }
                                    }

                                    StyledText { 
                                        text: modelData
                                        Layout.fillWidth: true
                                        color: isHidden ? Theme.surfaceVariantText : Theme.surfaceText
                                        font.weight: isHidden ? Font.Normal : Font.Medium
                                        font.pixelSize: Theme.fontSizeSmall
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: isHidden ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.05) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        DankIcon { 
                                            name: isHidden ? "visibility_off" : "visibility"
                                            size: 15
                                            color: isHidden ? Theme.surfaceVariantText : Theme.primary
                                            anchors.centerIn: parent
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: maVisibility
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let list = Array.from(root.hiddenProviders);
                                        let idx = list.indexOf(modelData);
                                        if (idx === -1) list.push(modelData);
                                        else list.splice(idx, 1);
                                        root.hiddenProviders = list;
                                        root.saveHidden(list);
                                    }
                                    onPressed: (m) => ripVisibility.trigger(m.x, m.y)
                                }
                                
                                DankRipple { id: ripVisibility; anchors.fill: parent; cornerRadius: root.innerR; rippleColor: Theme.primary }
                            }
                        }
                    }
                }
            }
        }

        // --- Custom Presets Section ---
        Column {
            width: parent.width
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "dns"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Custom Presets"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: customInnerCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                Column {
                    id: customInnerCol
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Add your own custom DNS providers to the switcher"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    // Add Form Card
                    Rectangle {
                        width: parent.width
                        implicitHeight: formCol.implicitHeight + Theme.spacingM * 2
                        radius: 10
                        color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.35)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                        border.width: 1

                        Column {
                            id: formCol
                            width: parent.width - Theme.spacingM * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            function handleAddPreset() {
                                let nameVal = newName.text;
                                let ipVal = newIp.text;
                                let iconVal = newIcon.text;
                                if (root.addCustomProvider(nameVal, ipVal, iconVal)) {
                                    newName.text = "";
                                    newIp.text = "";
                                    newIcon.text = "";
                                }
                            }

                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS
                                DankTextField {
                                    id: newName
                                    Layout.fillWidth: true
                                    placeholderText: "Preset Name (e.g. AdGuard Home)"
                                    onAccepted: formCol.handleAddPreset()
                                }
                                DankTextField {
                                    id: newIcon
                                    width: 110
                                    placeholderText: "Icon (dns)"
                                    onAccepted: formCol.handleAddPreset()
                                }
                            }
                            
                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS
                                DankTextField {
                                    id: newIp
                                    Layout.fillWidth: true
                                    placeholderText: "IP Addresses (e.g. 1.1.1.1, 1.0.0.1)"
                                    onAccepted: formCol.handleAddPreset()
                                }

                                Rectangle {
                                    id: addBtn
                                    width: 38
                                    height: 38
                                    radius: 8
                                    readonly property bool canAdd: (newName.text || "").trim().length > 0 && (newIp.text || "").trim().length > 0
                                    color: canAdd ? Theme.primary : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.6)
                                    scale: addBtnArea.pressed ? 0.92 : (addBtnArea.containsMouse && canAdd ? 1.06 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    DankIcon {
                                        name: "add"
                                        size: 20
                                        color: addBtn.canAdd ? Theme.surface : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: addBtnArea
                                        anchors.fill: parent
                                        enabled: addBtn.canAdd
                                        hoverEnabled: addBtn.canAdd
                                        cursorShape: addBtn.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: formCol.handleAddPreset()
                                        onPressed: (m) => addRip.trigger(m.x, m.y)
                                    }
                                    DankRipple { id: addRip; anchors.fill: parent; cornerRadius: 8; rippleColor: Theme.surface }
                                }
                            }
                        }
                    }

                    // Custom Presets List
                    Column {
                        width: parent.width
                        spacing: 2
                        visible: root.customProviders && root.customProviders.length > 0

                        Repeater {
                            model: root.customProvidersModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 48
                                color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1

                                property bool isFirst: index === 0
                                property bool isLast: index === (root.customProviders.length - 1)
                                property bool isSingle: (root.customProviders.length === 1)

                                topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
                                topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
                                bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
                                bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 6
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                        Layout.alignment: Qt.AlignVCenter

                                        DankIcon {
                                            name: (modelData && modelData.icon) ? modelData.icon : "dns"
                                            size: 18
                                            color: Theme.primary
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1
                                        StyledText { text: (modelData && modelData.name) ? modelData.name : ""; font.weight: Font.Medium; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                        StyledText { text: (modelData && modelData.ip) ? modelData.ip : ""; font.pixelSize: Theme.fontSizeSmall - 2; font.family: "Monospace"; color: Theme.primary; opacity: 0.7 }
                                    }

                                    Item {
                                        width: 30
                                        height: 30
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 15
                                            color: delMa.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : "transparent"
                                            scale: delMa.pressed ? 0.9 : (delMa.containsMouse ? 1.1 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            DankIcon {
                                                name: "delete"
                                                size: 16
                                                color: delMa.containsMouse ? Theme.error : Theme.surfaceVariantText
                                                anchors.centerIn: parent
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            MouseArea {
                                                id: delMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deleteCustomProvider(index)
                                                onPressed: (m) => ripDelete.trigger(m.x, m.y)
                                            }
                                            DankRipple { id: ripDelete; anchors.fill: parent; cornerRadius: 15; rippleColor: Theme.error }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

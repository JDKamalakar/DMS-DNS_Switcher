import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root
    
    popoutWidth: 320
    popoutHeight: 0

    // --- CC Support ---
    ccWidgetIcon: "dns"
    ccWidgetPrimaryText: "DNS Settings"
    ccWidgetSecondaryText: root.providerName === "System Default" ? "Automatic" : root.providerName
    ccWidgetIsActive: root.isManualDns
    ccDetailHeight: 480
    onCcWidgetExpanded: root.refresh()
    
    ccDetailContent: Component {
        ScrollView {
            anchors.fill: parent
            clip: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            
            Loader {
                width: parent.width
                sourceComponent: dnsWidgetContent
                readonly property bool inCC: true
            }
        }
    }

    Component.onCompleted: {
        root.updateProviders();
        console.log("DNS Switcher Plugin Loaded: " + root.providerName);
    }

    // --- State Management ---
    property string activeConnection: ""
    property string currentDns: ""
    property bool isManualDns: false
    property string statusLabel: activeConnection ? (isManualDns ? "Manual DNS active" : "Using DHCP") : "No active connection"
    property string providerName: "Unknown"
    property bool loading: connScanner.running || dnsScanner.running || setter.running

    // --- Settings & Reactivity ---
    property string _hiddenProviders: PluginService.loadPluginData("dnsSwitcher", "hiddenProviders", "[]")
    property string _customProviders: PluginService.loadPluginData("dnsSwitcher", "customProviders", "[]")

    PluginGlobalVar { varName: "hiddenProviders"; onValueChanged: { root._hiddenProviders = value; root.updateProviders() } }
    PluginGlobalVar { varName: "customProviders"; onValueChanged: { root._customProviders = value; root.updateProviders() } }

    property var providers: []

    function updateProviders() {
        let hidden = [];
        try { hidden = JSON.parse(root._hiddenProviders); } catch(e) { hidden = []; }
        
        let custom = [];
        try { custom = JSON.parse(root._customProviders); } catch(e) { custom = []; }

        let defaults = [
            { name: "System Default", ip: "", icon: "cloud_off" },
            { name: "Google", ip: "8.8.8.8, 8.8.4.4", icon: "assets/icons/google.svg" },
            { name: "Cloudflare", ip: "1.1.1.1, 1.0.0.1", icon: "assets/icons/cloudflare.svg" },
            { name: "OpenDNS", ip: "208.67.222.222, 208.67.220.220", icon: "assets/icons/opendns.svg" },
            { name: "AdGuard", ip: "94.140.14.14, 94.140.15.15", icon: "assets/icons/adguard.svg" },
            { name: "Quad9", ip: "9.9.9.9, 149.112.112.112", icon: "assets/icons/quad9.svg" }
        ];

        let filtered = defaults.filter(p => hidden.indexOf(p.name) === -1);
        root.providers = filtered.concat(custom);
    }

    readonly property string currentIcon: {
        for (let p of providers) {
            if (p.name === providerName) return p.icon;
        }
        return "dns";
    }

    function getProvider(ips) {
        if (!ips) return "System Default";
        let clean = ips.replace(/[\s,]+/g, " ").trim();
        for (let p of providers) {
            if (!p.ip) continue;
            let pClean = p.ip.replace(/[\s,]+/g, " ").trim();
            if (pClean === clean || clean.includes(p.ip.split(/[\s,]+/)[0].trim())) {
                return p.name;
            }
        }
        return "Custom";
    }

    // --- Scanners ---
    Process {
        id: connScanner
        command: ["bash", "-c", "nmcli -t -f NAME connection show --active | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeConnection = text.trim();
                if (root.activeConnection) {
                    dnsScanner.running = false;
                    dnsScanner.running = true;
                }
            }
        }
    }

    Process {
        id: dnsScanner
        running: false
        command: ["bash", "-c", `dns="$(resolvectl status | grep 'DNS Servers' | sed 's/.*DNS Servers:[ \t]*//')"; man="$(nmcli -g ipv4.ignore-auto-dns connection show "${root.activeConnection}")"; echo "$dns|$man"`]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split('|');
                let dnsLine = parts[0] ? parts[0].trim().replace(/\r?\n/g, " ") : "";
                let manual = parts[1] ? parts[1].trim() === "yes" : false;
                
                root.currentDns = dnsLine;
                root.isManualDns = manual;
                root.providerName = root.isManualDns ? root.getProvider(root.currentDns) : "System Default";
            }
        }
    }

    function refresh() {
        connScanner.running = false;
        connScanner.running = true;
    }

    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // --- Setter ---
    Process {
        id: setter
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("DNS set successfully.");
                root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    console.log("DNS Setter Error: " + text.trim());
                }
            }
        }
    }

    function setDns(ips) {
        setter.running = false;
        let cleanIps = ips.replace(/,\s*/g, " ");
        let cmd = "";
        if (cleanIps === "") {
            // Reset to DHCP
            cmd = `nmcli con mod "${root.activeConnection}" ipv4.dns "" ipv4.ignore-auto-dns no && nmcli con up "${root.activeConnection}"`;
        } else {
            cmd = `nmcli con mod "${root.activeConnection}" ipv4.dns "${cleanIps}" ipv4.ignore-auto-dns yes && nmcli con up "${root.activeConnection}"`;
        }
        setter.command = ["bash", "-c", cmd];
        setter.running = true;
    }

    // --- Bar Pill ---
    horizontalBarPill: Component {
        RowLayout {
            id: pillRowH; spacing: 6; anchors.verticalCenter: parent.verticalCenter
            Item {
                width: Theme.iconSize - 4; height: Theme.iconSize - 4
                Layout.alignment: Qt.AlignVCenter
                Loader {
                    id: pillIconLoaderH
                    anchors.fill: parent
                    sourceComponent: root.loading ? refreshingIconComp : (root.currentIcon.includes("/") ? customPillIconH : standardPillIconH)
                    
                    readonly property string _trigger: root.loading + "|" + root.currentIcon
                    on_TriggerChanged: pillIconAnimH.restart()
                    
                    transform: Translate { id: pillIconTransH }
                    SequentialAnimation {
                        id: pillIconAnimH
                        ParallelAnimation {
                            NumberAnimation { target: pillIconLoaderH; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                            NumberAnimation { target: pillIconTransH; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                        }
                        PropertyAction { target: pillIconTransH; property: "y"; value: -5 }
                        ParallelAnimation {
                            NumberAnimation { target: pillIconLoaderH; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                            NumberAnimation { target: pillIconTransH; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        }
                    }
                    
                    Component { id: standardPillIconH; DankIcon { name: root.currentIcon; size: Theme.iconSize - 4; color: Theme.widgetIconColor || Theme.primary; anchors.centerIn: parent } }
                    Component { 
                        id: customPillIconH
                        Item {
                            anchors.fill: parent
                            Image { id: pillImgH; source: Qt.resolvedUrl(root.currentIcon); anchors.fill: parent; sourceSize.width: 24; sourceSize.height: 24; visible: false; smooth: true }
                            ColorOverlay { anchors.fill: pillImgH; source: pillImgH; color: Theme.widgetIconColor || Theme.primary }
                        }
                    }
                }
            }
            Item {
                height: 20; Layout.fillWidth: false; Layout.preferredWidth: Math.max(pillTextH.implicitWidth, 60); Layout.alignment: Qt.AlignVCenter
                StyledText { 
                    id: pillTextH
                    text: root.loading ? "Changing..." : (root.providerName === "System Default" ? "Auto" : root.providerName)
                    font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Medium
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    
                    onTextChanged: pillTextAnimH.restart()
                    transform: Translate { id: pillTextTransH }
                    SequentialAnimation {
                        id: pillTextAnimH
                        ParallelAnimation {
                            NumberAnimation { target: pillTextH; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                            NumberAnimation { target: pillTextTransH; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                        }
                        PropertyAction { target: pillTextTransH; property: "y"; value: -5 }
                        ParallelAnimation {
                            NumberAnimation { target: pillTextH; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                            NumberAnimation { target: pillTextTransH; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            width: 18; height: 18
            anchors.horizontalCenter: parent.horizontalCenter
            Loader {
                id: pillIconLoaderV
                anchors.fill: parent
                sourceComponent: root.loading ? refreshingIconComp : (root.currentIcon.includes("/") ? customPillIconV : standardPillIconV)
                
                readonly property string _trigger: root.loading + "|" + root.currentIcon
                on_TriggerChanged: pillIconAnimV.restart()
                
                transform: Translate { id: pillIconTransV }
                SequentialAnimation {
                    id: pillIconAnimV
                    ParallelAnimation {
                        NumberAnimation { target: pillIconLoaderV; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pillIconTransV; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                    }
                    PropertyAction { target: pillIconTransV; property: "y"; value: -5 }
                    ParallelAnimation {
                        NumberAnimation { target: pillIconLoaderV; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                        NumberAnimation { target: pillIconTransV; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                    }
                }

                Component { id: standardPillIconV; DankIcon { name: root.currentIcon; size: 18; color: Theme.widgetIconColor || Theme.primary; anchors.centerIn: parent } }
                Component { 
                    id: customPillIconV
                    Item {
                        anchors.fill: parent
                        Image { id: pillImgV; source: Qt.resolvedUrl(root.currentIcon); anchors.fill: parent; sourceSize.width: 24; sourceSize.height: 24; visible: false; smooth: true }
                        ColorOverlay { anchors.fill: pillImgV; source: pillImgV; color: Theme.widgetIconColor || Theme.primary }
                    }
                }
            }
        }
    }

    Component {
        id: refreshingIconComp
        DankIcon {
            name: "cached"; size: parent.width; color: Theme.widgetIconColor || Theme.primary
            anchors.centerIn: parent
            RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
        }
    }

    // --- Popout Content ---
    popoutContent: Component {
        PopoutComponent {
            id: popoutContainer
            headerText: ""
            detailsText: ""
            showCloseButton: false
            
            Loader {
                width: parent.width
                sourceComponent: dnsWidgetContent
                readonly property bool inCC: false
            }
        }
    }

    Component {
        id: dnsWidgetContent
        Column {
            id: mainCol; width: parent.width; spacing: Theme.spacingM
            readonly property bool inCC: (parent && parent.inCC) || false
            padding: inCC ? 16 : 0
            topPadding: 0
            bottomPadding: inCC ? 16 : 2

                StyledRect {
                    width: parent.width - (mainCol.inCC ? 32 : 0); anchors.horizontalCenter: parent.horizontalCenter; height: 72
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Rectangle {
                            width: 42; height: 42; radius: 21; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            Item {
                                width: 24; height: 24
                                anchors.centerIn: parent
                                Loader {
                                    id: headerIconLoader
                                    anchors.fill: parent
                                    sourceComponent: root.loading ? refreshingIconCompHeader : (root.currentIcon.includes("/") ? customHeaderIcon : standardHeaderIcon)
                                    
                                    readonly property string _trigger: root.loading ? "loading" : root.currentIcon
                                    on_TriggerChanged: iconAnim.restart()
                                    
                                    transform: Translate { id: iconTransH }
                                    SequentialAnimation {
                                        id: iconAnim
                                        ParallelAnimation {
                                            NumberAnimation { target: headerIconLoader; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: iconTransH; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                        }
                                        PropertyAction { target: iconTransH; property: "y"; value: -5 }
                                        ParallelAnimation {
                                            NumberAnimation { target: headerIconLoader; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                                            NumberAnimation { target: iconTransH; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 0
                            StyledText { 
                                id: connectionNameText
                                Layout.fillWidth: true
                                text: root.activeConnection || "No Connection"
                                font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText 
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                
                                onTextChanged: connNameAnim.restart()
                                transform: Translate { id: connTrans }
                                SequentialAnimation {
                                    id: connNameAnim
                                    ParallelAnimation {
                                        NumberAnimation { target: connectionNameText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: connTrans; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                    }
                                    PropertyAction { target: connTrans; property: "y"; value: -5 }
                                    ParallelAnimation {
                                        NumberAnimation { target: connectionNameText; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                                        NumberAnimation { target: connTrans; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                            StyledText { 
                                id: statusLabelText
                                Layout.fillWidth: true
                                text: root.statusLabel
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                                font.family: "Monospace"
                                opacity: 0.8
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Item {
                            width: 38
                            height: 38
                            Layout.alignment: Qt.AlignVCenter
                            scale: refreshArea.pressed ? 0.9 : (refreshArea.containsMouse ? 1.1 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            MouseArea {
                                id: refreshArea
                                anchors.fill: parent
                                hoverEnabled: !root.loading
                                enabled: !root.loading
                                cursorShape: root.loading ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onPressed: mouse => refreshRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    root.refresh()
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: refreshArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, refreshArea.containsMouse ? 0.3 : 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            DankIcon {
                                id: refreshIcon
                                name: root.loading ? "cached" : "refresh"
                                size: 20
                                color: Theme.primary
                                anchors.centerIn: parent

                                SequentialAnimation {
                                    id: hoverSpinAnim
                                    running: refreshArea.containsMouse && !root.loading
                                    onStopped: refreshIcon.rotation = 0
                                    NumberAnimation { target: refreshIcon; property: "rotation"; from: 0; to: 45; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: refreshIcon; property: "rotation"; from: 45; to: -45; duration: 400; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: refreshIcon; property: "rotation"; from: -45; to: 0; duration: 200; easing.type: Easing.InQuad }
                                }

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite; running: root.loading
                                }
                            }

                            DankRipple {
                                id: refreshRipple
                                rippleColor: Theme.surfaceText
                                cornerRadius: Theme.cornerRadius
                                anchors.fill: parent
                            }
                        }
                    }

                    Component {
                        id: standardHeaderIcon
                        DankIcon { name: root.currentIcon; size: 24; color: Theme.primary; anchors.centerIn: parent }
                    }
                    Component {
                        id: customHeaderIcon
                        Item {
                            width: 24; height: 24
                            Image {
                                id: headerImg; source: Qt.resolvedUrl(root.currentIcon); anchors.fill: parent
                                sourceSize.width: 24; sourceSize.height: 24; visible: false; smooth: true
                            }
                            ColorOverlay {
                                anchors.fill: headerImg; source: headerImg; color: Theme.primary
                            }
                        }
                    }
                    Component {
                        id: refreshingIconCompHeader
                        DankIcon {
                            name: "cached"; size: 24; color: Theme.primary
                            anchors.centerIn: parent
                            RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                        }
                    }
                }

                StyledRect {
                    width: parent.width - (mainCol.inCC ? 32 : 0); height: 50
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        DankIcon { name: "settings_ethernet"; size: 16; color: Theme.surfaceText; opacity: 0.7 }
                        Item {
                            Layout.fillWidth: true; height: 18
                            StyledText { 
                                id: providerNameLabel
                                width: parent.width
                                text: "Current DNS: " + root.providerName
                                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText
                                
                                onTextChanged: providerNameAnim.restart()
                                transform: Translate { id: provNameTrans }
                                SequentialAnimation {
                                    id: providerNameAnim
                                    ParallelAnimation {
                                        NumberAnimation { target: providerNameLabel; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: provNameTrans; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                    }
                                    PropertyAction { target: provNameTrans; property: "y"; value: -5 }
                                    ParallelAnimation {
                                        NumberAnimation { target: providerNameLabel; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
                                        NumberAnimation { target: provNameTrans; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                        }
                        Item {
                            width: 100; height: 18
                            StyledText {
                                id: providerIpLabel
                                width: parent.width
                                text: root.currentDns ? root.currentDns.split(/[\s,]+/)[0] : "192.168.1.1"
                                font.pixelSize: Theme.fontSizeSmall - 2; font.family: "Monospace"; color: Theme.primary; opacity: 0.6
                                horizontalAlignment: Text.AlignRight
                                
                                onTextChanged: providerIpAnim.restart()
                                transform: Translate { id: provIpTrans }
                                SequentialAnimation {
                                    id: providerIpAnim
                                    ParallelAnimation {
                                        NumberAnimation { target: providerIpLabel; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: provIpTrans; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                    }
                                    PropertyAction { target: provIpTrans; property: "y"; value: -5 }
                                    ParallelAnimation {
                                        NumberAnimation { target: providerIpLabel; property: "opacity"; to: 0.6; duration: 150; easing.type: Easing.InQuad }
                                        NumberAnimation { target: provIpTrans; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    id: presetsCont
                    width: parent.width - (mainCol.inCC ? 32 : 0)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: presetsContentCol.implicitHeight + Theme.spacingM * 2
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Column {
                        id: presetsContentCol
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 4; anchors.rightMargin: 4
                            spacing: Theme.spacingXS; width: parent.width
                            DankIcon { name: "bolt"; size: 14; color: Theme.surfaceText }
                            StyledText { text: "Quick Presets"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        Column {
                            id: presetsList; width: parent.width; spacing: 4
                            enabled: !root.loading
                            opacity: root.loading ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            
                            Repeater {
                                model: root.providers
                                delegate: Item {
                                     id: presetItem; width: presetsList.width; height: 44
                                     property bool hovered: maPreset.containsMouse
                                     property bool isActive: root.providerName === modelData.name

                                     MouseArea {
                                         id: maPreset; anchors.fill: parent; hoverEnabled: !root.loading
                                         enabled: !root.loading
                                         cursorShape: root.loading ? Qt.ArrowCursor : Qt.PointingHandCursor
                                         onClicked: root.setDns(modelData.ip)
                                         onPressed: (m) => pRip.trigger(m.x, m.y)
                                     }

                                     Canvas {
                                         id: presetBg; anchors.fill: parent
                                         property real innerRadius: 6
                                         property real outerRadius: 12
                                         property bool isFirst: index === 0
                                         property bool isLast: index === root.providers.length - 1
                                         
                                         property real tlr: isActive ? 21.5 : (isFirst ? outerRadius : innerRadius)
                                         property real trr: isActive ? 21.5 : (isFirst ? outerRadius : innerRadius)
                                         property real blr: isActive ? 21.5 : (isLast ? outerRadius : innerRadius)
                                         property real brr: isActive ? 21.5 : (isLast ? outerRadius : innerRadius)

                                         property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                         property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                         property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                         property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                                         property color paintColor: isActive
                                             ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                             : hovered
                                                 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                                 : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                         
                                         property color paintBorder: isActive
                                             ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                             : hovered
                                                 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                                 : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)

                                         onTlrAnimChanged: requestPaint()
                                         onTrrAnimChanged: requestPaint()
                                         onBlrAnimChanged: requestPaint()
                                         onBrrAnimChanged: requestPaint()
                                         onPaintColorChanged: requestPaint()
                                         onPaintBorderChanged: requestPaint()

                                         onPaint: {
                                             var ctx = getContext("2d");
                                             var x = 0.5, y = 0.5;
                                             var w = width - 1, h = height - 1;
                                             
                                             ctx.reset();
                                             ctx.beginPath();
                                             ctx.moveTo(x + tlrAnim, y);
                                             ctx.lineTo(x + w - trrAnim, y);
                                             ctx.arcTo(x + w, y, x + w, y + trrAnim, trrAnim);
                                             ctx.lineTo(x + w, y + h - brrAnim);
                                             ctx.arcTo(x + w, y + h, x + w - brrAnim, y + h, brrAnim);
                                             ctx.lineTo(x + blrAnim, y + h);
                                             ctx.arcTo(x, y + h, x, y + h - blrAnim, blrAnim);
                                             ctx.lineTo(x, y + tlrAnim);
                                             ctx.arcTo(x, y, x + tlrAnim, y, tlrAnim);
                                             ctx.closePath();
                                             
                                             ctx.fillStyle = paintColor;
                                             ctx.fill();
                                             ctx.strokeStyle = paintBorder;
                                             ctx.lineWidth = 1;
                                             ctx.stroke();
                                         }

                                         Rectangle { 
                                             anchors.fill: parent; radius: parent.tlrAnim; color: "white"
                                             anchors.margins: 0.5
                                             opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } 
                                         }
                                     }

                                     DankRipple { id: pRip; anchors.fill: parent; cornerRadius: presetBg.tlrAnim; rippleColor: Theme.primary }

                                     RowLayout {
                                         anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: Theme.spacingS
                                         Loader {
                                             Layout.preferredWidth: 18
                                             Layout.preferredHeight: 18
                                             sourceComponent: modelData.icon.includes("/") ? customIconComp : standardIconComp
                                             
                                             Component {
                                                 id: standardIconComp
                                                 DankIcon { 
                                                     name: modelData.icon; size: 18
                                                     color: isActive ? Theme.primary : Theme.surfaceVariantText
                                                     anchors.centerIn: parent
                                                     Behavior on color { ColorAnimation { duration: 200 } }
                                                 }
                                             }

                                             Component {
                                                 id: customIconComp
                                                 Item {
                                                     width: 18; height: 18
                                                     Image {
                                                         id: imgIcon
                                                         source: Qt.resolvedUrl(modelData.icon)
                                                         anchors.fill: parent
                                                         sourceSize.width: 18
                                                         sourceSize.height: 18
                                                         visible: false
                                                         smooth: true
                                                     }
                                                     ColorOverlay {
                                                         anchors.fill: imgIcon
                                                         source: imgIcon
                                                         color: isActive ? Theme.primary : Theme.surfaceVariantText
                                                         Behavior on color { ColorAnimation { duration: 200 } }
                                                     }
                                                 }
                                             }
                                         }
                                         StyledText { 
                                             text: modelData.name; font.pixelSize: Theme.fontSizeSmall
                                             font.weight: isActive ? Font.Bold : Font.Normal 
                                             color: isActive ? Theme.primary : Theme.surfaceText
                                             Layout.fillWidth: true 
                                             Behavior on color { ColorAnimation { duration: 200 } }
                                         }
                                         DankIcon { 
                                             name: "check_circle"; size: 16; color: Theme.primary
                                             scale: isActive ? 1.0 : 0.0
                                             opacity: isActive ? 1.0 : 0.0
                                             Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                             Behavior on opacity { NumberAnimation { duration: 200 } }
                                         }
                                     }
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    id: customCont
                    width: parent.width - (mainCol.inCC ? 32 : 0); height: customCol.implicitHeight + Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Column {
                        id: customCol; anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        enabled: !root.loading
                        opacity: root.loading ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        
                        RowLayout {
                            width: parent.width; spacing: Theme.spacingXS
                            DankIcon { name: "edit"; size: 14; color: Theme.surfaceText }
                            StyledText { text: "Custom Config"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        RowLayout {
                            width: parent.width; spacing: Theme.spacingS
                            DankTextField {
                                id: customDnsInput; Layout.fillWidth: true; placeholderText: "8.8.8.8, 1.1.1.1"; font.pixelSize: Theme.fontSizeSmall
                                text: (root.providerName === "Custom") ? root.currentDns : ""
                                onAccepted: if (saveBtnContainer.canSave) root.setDns(text.trim())
                            }
                            Item {
                                id: saveBtnContainer
                                width: 38
                                height: 38
                                property bool hasText: customDnsInput.text.trim().length > 0
                                property bool isDifferent: customDnsInput.text.trim() !== root.currentDns
                                property bool canSave: hasText && isDifferent

                                scale: canSave ? (saveArea.pressed ? 0.9 : (saveArea.containsMouse ? 1.1 : 1.0)) : 1.0
                                opacity: canSave ? 1.0 : 0.3
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                MouseArea {
                                    id: saveArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: parent.canSave
                                    cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onEntered: if (parent.canSave) saveHoverAnim.restart()
                                    onPressed: mouse => saveRipple.trigger(mouse.x, mouse.y)
                                    onClicked: root.setDns(customDnsInput.text.trim())
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: saveArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, saveArea.containsMouse ? 0.3 : 0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                }

                                DankIcon {
                                    id: saveIcon
                                    name: "done"
                                    size: 20
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                    
                                    SequentialAnimation {
                                        id: saveHoverAnim
                                        onStopped: saveIcon.rotation = 0
                                        NumberAnimation { target: saveIcon; property: "rotation"; from: 0; to: 15; duration: 200; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: saveIcon; property: "rotation"; from: 15; to: -15; duration: 400; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: saveIcon; property: "rotation"; from: -15; to: 0; duration: 200; easing.type: Easing.InQuad }
                                    }
                                }

                                DankRipple {
                                    id: saveRipple
                                    rippleColor: Theme.surfaceText
                                    cornerRadius: Theme.cornerRadius
                                    anchors.fill: parent
                                }
                            }
                        }

                    }
                }
        }
    }
}

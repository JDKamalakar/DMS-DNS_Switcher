import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root
    
    popoutWidth: 320
    popoutHeight: 0

    Component.onCompleted: {
        console.log("DNS Tile Plugin Loaded: " + root.providerName);
    }

    // --- State Management ---
    property string activeConnection: ""
    property string currentDns: ""
    property bool isManualDns: false
    property string statusLabel: activeConnection ? (isManualDns ? "Manual DNS active" : "Using DHCP") : "No active connection"
    property string providerName: "Unknown"
    property bool loading: connScanner.running || dnsScanner.running || setter.running

    // --- DNS Providers ---
    readonly property var providers: [
        { name: "Google", ip: "8.8.8.8, 8.8.4.4", icon: "dns" },
        { name: "Cloudflare", ip: "1.1.1.1, 1.0.0.1", icon: "security" },
        { name: "OpenDNS", ip: "208.67.222.222, 208.67.220.220", icon: "public" },
        { name: "AdGuard", ip: "94.140.14.14, 94.140.15.15", icon: "verified_user" },
        { name: "Quad9", ip: "9.9.9.9, 149.112.112.112", icon: "lock" }
    ]

    function getProvider(ips) {
        if (!ips) return "Automatic";
        let clean = ips.replace(/[\s,]+/g, " ").trim();
        for (let p of providers) {
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
                root.providerName = root.isManualDns ? root.getProvider(root.currentDns) : "System Default (DHCP)";
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
        DankIcon {
            name: "dns"; size: Theme.iconSize - 4; color: Theme.widgetIconColor || Theme.primary; anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "dns"; size: 20; color: Theme.widgetIconColor || Theme.primary; anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // --- Popout Content ---
    popoutContent: Component {
        PopoutComponent {
            id: popoutContainer
            headerText: ""
            detailsText: ""
            showCloseButton: false
            
            Column {
                id: mainCol; width: parent.width; spacing: Theme.spacingM
                topPadding: 0; bottomPadding: 2

                // --- Header Card ---
                StyledRect {
                    width: parent.width; height: 72
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
                            DankIcon { name: "settings_ethernet"; size: 24; color: Theme.primary; anchors.centerIn: parent }
                        }
                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                            StyledText { 
                                text: root.activeConnection || "No Connection"
                                font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText 
                                elide: Text.ElideRight; width: parent.width
                                Behavior on text { SequentialAnimation { NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 100 } PropertyAction {} NumberAnimation { target: parent; property: "opacity"; to: 1; duration: 100 } } }
                            }
                            StyledText { 
                                text: root.statusLabel
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                                font.family: "Monospace"
                                opacity: 0.8
                            }
                        }
                        DankIcon {
                            name: root.loading ? "cached" : "refresh"
                            size: 18; color: Theme.primary; opacity: 0.6
                            rotation: 0
                            Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                            
                            RotationAnimation on rotation { 
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.loading 
                            }
                            MouseArea { anchors.fill: parent; onClicked: { parent.rotation += 360; root.refresh() } }
                        }
                    }
                }

                // --- Current Provider Section ---
                StyledRect {
                    width: parent.width; height: 50
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        DankIcon { name: "public"; size: 16; color: Theme.surfaceText; opacity: 0.7 }
                        StyledText { 
                            text: "Current DNS: " + root.providerName
                            font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText
                            Layout.fillWidth: true
                            Behavior on text { SequentialAnimation { NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 100 } PropertyAction {} NumberAnimation { target: parent; property: "opacity"; to: 1; duration: 100 } } }
                        }
                        StyledText {
                            text: root.currentDns ? root.currentDns.split(/[\s,]+/)[0] : "192.168.1.1"
                            font.pixelSize: Theme.fontSizeSmall - 2; font.family: "Monospace"; color: Theme.primary; opacity: 0.6
                        }
                    }
                }

                StyledRect {
                    id: presetsCont
                    width: parent.width
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
                            Repeater {
                                model: root.providers
                                delegate: Item {
                                     id: presetItem; width: presetsList.width; height: 44
                                     property bool hovered: maPreset.containsMouse
                                     property bool isActive: root.providerName === modelData.name

                                     MouseArea {
                                         id: maPreset; anchors.fill: parent; hoverEnabled: true
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
                                         DankIcon { 
                                             name: modelData.icon; size: 18
                                             color: isActive ? Theme.primary : Theme.surfaceVariantText
                                             Behavior on color { ColorAnimation { duration: 200 } }
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
                    width: parent.width; height: customCol.implicitHeight + Theme.spacingM * 2
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
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 18; color: Theme.primary
                                DankIcon { name: "done"; size: 18; color: "white"; anchors.centerIn: parent }
                                MouseArea { 
                                    anchors.fill: parent; onClicked: if (customDnsInput.text) root.setDns(customDnsInput.text.trim())
                                    onPressed: (m) => doneRip.trigger(m.x, m.y)
                                }
                                DankRipple { id: doneRip; anchors.fill: parent; cornerRadius: 18; rippleColor: "white" }
                            }
                        }

                        StyledRect {
                            width: parent.width; height: 40; radius: 8
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
                            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2); border.width: 1
                            opacity: root.isManualDns ? 1 : 0.5
                            
                            RowLayout {
                                anchors.centerIn: parent; spacing: 8
                                DankIcon { name: "restart_alt"; size: 16; color: Theme.error }
                                StyledText { text: "Reset to System Default (DHCP)"; color: Theme.error; font.pixelSize: Theme.fontSizeSmall - 1; font.bold: true }
                            }
                            MouseArea { 
                                anchors.fill: parent; enabled: root.isManualDns; onClicked: root.setDns("")
                                onPressed: (m) => resetRip.trigger(m.x, m.y)
                            }
                            DankRipple { id: resetRip; anchors.fill: parent; cornerRadius: 8; rippleColor: Theme.error }
                        }
                    }
                }
            }
        }
    }
}

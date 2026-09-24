import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "model/TouchesModel.js" as Model

// Moteur + bandeau d'affichage des frappes, dans le style terminal à phosphore
// des autres outils (minuteur, tirage au sort).
//
// Quand l'affichage est actif, un handler Lua d'une ligne, enregistré via
// « hyprctl repl », republie chaque événement clavier en événement socket2 que
// ce service consomme. Inactif = handler retiré, le compositeur ne fait plus
// rien par touche. Aucune frappe n'est écrite sur disque.
//
// Mécanisme repris de community.keycast (devmobasa, MIT) ; libellés, réduction
// en accords et apparence réécrits ici.
Item {
    id: root

    property var shell: null

    property bool enabled: false
    property var hudState: Model.emptyState()
    property string layout: "qwerty"
    property string lastError: ""

    // Dernier événement reçu, pour écarter les doublons (voir DEDUPE_MS).
    property int lastCode: -1
    property bool lastPressed: false
    property real lastAt: 0

    readonly property color green: "#33ff66"
    readonly property color dim: "#020803"
    readonly property string mono: "JetBrainsMono Nerd Font"

    // Le bandeau suit l'écran actif (le vidéoprojecteur quand on y présente).
    readonly property var hudScreen: {
        const screens = Quickshell.screens || []
        const focused = Hyprland.focusedMonitor
        for (let i = 0; i < screens.length; i++)
            if (focused && Hyprland.monitorFor(screens[i]) === focused) return screens[i]
        return screens.length > 0 ? screens[0] : null
    }

    function run(proc) {
        proc.exitSeen = false
        proc.running = true
    }

    function setEnabled(value) {
        const next = value === true
        if (next === enabled) return
        lastError = ""
        enabled = next
        hudState = Model.emptyState()
        if (next) detectLayout()
        replProcess.command = ["hyprctl", "repl", next ? Model.REGISTER_LUA : Model.UNREGISTER_LUA]
        run(replProcess)
    }

    function detectLayout() {
        layoutProcess.running = true
    }

    // Disposition active : les libellés en dépendent (bépo, azerty, qwerty).
    Process {
        id: layoutProcess
        command: ["sh", "-c", "hyprctl devices -j | jq -r '[.keyboards[].active_keymap] | first // \"\"'"]
        stdout: StdioCollector {
            onStreamFinished: root.layout = Model.layoutKey(this.text.trim())
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "custom") {
                if (!root.enabled) return
                const parsed = Model.parseEvent(event.data)
                if (parsed === null) return
                const at = Date.now()
                if (parsed.code === root.lastCode && parsed.pressed === root.lastPressed
                    && at - root.lastAt < Model.DEDUPE_MS) return
                root.lastCode = parsed.code
                root.lastPressed = parsed.pressed
                root.lastAt = at
                root.hudState = Model.applyEvent(root.hudState, parsed, root.layout)
                if (parsed.pressed) idleTimer.restart()
            } else if (event.name === "activelayout" && root.enabled) {
                root.detectLayout()
            } else if (event.name === "configreloaded" && root.enabled) {
                // La VM Lua du repl est réinitialisée : l'abonnement a disparu.
                replProcess.command = ["hyprctl", "repl", Model.REGISTER_LUA]
                root.run(replProcess)
            }
        }
    }

    // Le bandeau s'efface après un moment sans frappe.
    Timer {
        id: idleTimer
        interval: 3000
        onTriggered: root.hudState = Model.emptyState()
    }

    Process {
        id: replProcess
        property bool exitSeen: false
        command: ["hyprctl", "repl", ""]
        onRunningChanged: if (!running && !exitSeen) {
            root.lastError = "hyprctl n'a pas pu être lancé"
            root.enabled = false
        }
        onExited: exitCode => {
            exitSeen = true
            if (exitCode !== 0) {
                root.lastError = "l'enregistrement du handler a échoué"
                root.enabled = false
            }
        }
    }

    IpcHandler {
        target: "vianney.touches"

        function toggle(): string {
            root.setEnabled(!root.enabled)
            return root.enabled ? "on" : "off"
        }

        function enable(): string {
            root.setEnabled(true)
            return "on"
        }

        function disable(): string {
            root.setEnabled(false)
            return "off"
        }

        function status(): string {
            return JSON.stringify({
                "enabled": root.enabled,
                "layout": root.layout,
                "entries": root.hudState.entries.length,
                "error": root.lastError
            })
        }
    }

    // ---- Bandeau, en bas de l'écran actif ----
    PanelWindow {
        id: hud
        visible: root.enabled && root.hudState.entries.length > 0
        screen: root.hudScreen
        color: "transparent"
        WlrLayershell.namespace: "touches"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        anchors.bottom: true
        margins.bottom: 60

        // Bandeau traversant : ni clic ni focus ne s'y arrêtent.
        mask: Region {}

        Rectangle {
            id: frame
            anchors.centerIn: parent
            implicitWidth: chipRow.implicitWidth + 40
            implicitHeight: chipRow.implicitHeight + 28
            radius: 6
            color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.92)
            border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.4)
            border.width: 1

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌌"
                    color: root.green
                    opacity: 0.5
                    font.family: root.mono
                    font.pixelSize: 26
                }

                Repeater {
                    model: root.hudState.entries

                    Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool newest: index === root.hudState.entries.length - 1

                        implicitWidth: chipText.implicitWidth + 22
                        implicitHeight: chipText.implicitHeight + 12
                        radius: 4
                        color: newest ? Qt.rgba(root.green.r, root.green.g, root.green.b, 0.18) : "transparent"
                        border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, newest ? 0.7 : 0.25)
                        border.width: 1
                        opacity: newest ? 1 : 0.55

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: Model.entryLabel(parent.modelData)
                            color: root.green
                            font.family: root.mono
                            font.pixelSize: 26
                            font.bold: parent.newest
                        }
                    }
                }
            }

            // Halo phosphore, comme le minuteur et le tirage au sort.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.green
                shadowBlur: 0.7
                shadowOpacity: 0.7
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 24
            }
        }
    }
}

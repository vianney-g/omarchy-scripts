// Minuteur plein écran pour vidéoprojecteur — style terminal à phosphore.
// Lancement : qs -n -c minuteur   (raccourci SUPER + ALT + M)
//   Saisie   : tapez les minutes puis Entrée
//   Décompte : Espace = pause/reprise, R = recommencer
//   Partout  : Échap = quitter
// Pendant le décompte, le mode « stay awake » d'Omarchy est forcé, puis remis
// à son état initial à la fin (ou si on quitte avant).
// À 5 minutes de la fin : passage en ambre et bip discret ; dernière minute en rouge.
// La dernière durée utilisée est pré-remplie au lancement suivant.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    // "input" -> "running" -> "done"
    property string mode: "input"
    property bool paused: false
    property real endTime: 0          // horodatage (ms) de fin du décompte
    property int remainingMs: 0
    property int totalMinutes: 0
    property bool warned: false       // bip des 5 minutes déjà joué
    property date now: new Date()

    readonly property int warningSec: 5 * 60

    readonly property int remainingSec: Math.ceil(remainingMs / 1000)
    readonly property string display: {
        const m = Math.floor(remainingSec / 60)
        const s = remainingSec % 60
        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }

    // --- Palette phosphore ---
    readonly property color green: "#33ff66"
    readonly property color amber: "#ffb000"
    readonly property color red: "#ff3344"
    readonly property color accent:
        mode === "done" ? red
        : mode !== "running" ? green
        : remainingSec <= 60 ? red
        : remainingSec <= warningSec ? amber
        : green
    readonly property string mono: "JetBrainsMono Nerd Font"

    // Barre de progression ASCII (temps écoulé).
    readonly property real progress:
        totalMinutes > 0 ? 1 - remainingMs / (totalMinutes * 60000) : 0
    function progressBar(width) {
        const n = Math.round(progress * width)
        return "[" + "█".repeat(n) + "░".repeat(width - n) + "] "
             + String(Math.floor(progress * 100)).padStart(3, " ") + "%"
    }

    // --- Stay awake ---
    property var awakeInitial: null   // état au lancement (true/false), null tant qu'inconnu
    property bool awakeHeld: false    // true si le minuteur maintient le stay awake

    Process {
        running: true
        command: ["omarchy", "toggle", "idle", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.awakeInitial = JSON.parse(this.text).enabled === true }
                catch (e) { root.awakeInitial = false }
            }
        }
    }

    function holdAwake() {
        if (awakeHeld) return
        awakeHeld = true
        if (awakeInitial !== true)
            Quickshell.execDetached(["omarchy", "toggle", "idle", "stay-awake"])
    }

    function releaseAwake() {
        if (!awakeHeld) return
        awakeHeld = false
        if (awakeInitial !== true)
            Quickshell.execDetached(["omarchy", "toggle", "idle", "allow-idle"])
    }

    function quit() {
        releaseAwake()
        Qt.quit()
    }

    onModeChanged: if (mode === "done") { releaseAwake(); beep() }

    // --- Dernière durée utilisée ---
    FileView {
        id: lastDuration
        path: Quickshell.statePath("derniere-duree")
        blockLoading: true
        printErrors: false
    }

    // Bip discret à 5 minutes de la fin.
    function warnBeep() {
        Quickshell.execDetached(["sh", "-c",
            "pw-play /usr/share/sounds/freedesktop/stereo/bell.oga; sleep 0.15; pw-play /usr/share/sounds/freedesktop/stereo/bell.oga"])
    }

    // Sonnerie de fin (son système « réveil », ~6 s, jouée une fois).
    function beep() {
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    }

    function start(minutes) {
        holdAwake()
        lastDuration.setText(String(minutes))
        totalMinutes = minutes
        warned = minutes <= 5          // pas d'avertissement pour un décompte de 5 min ou moins
        remainingMs = minutes * 60000
        endTime = Date.now() + remainingMs
        paused = false
        mode = "running"
    }

    function togglePause() {
        if (mode !== "running") return
        if (paused) endTime = Date.now() + remainingMs
        paused = !paused
    }

    // On se base sur l'heure réelle plutôt que sur un compteur, pour éviter toute dérive.
    Timer {
        interval: 100
        repeat: true
        running: root.mode === "running" && !root.paused
        onTriggered: {
            root.remainingMs = Math.max(0, root.endTime - Date.now())
            if (!root.warned && root.remainingSec <= root.warningSec) {
                root.warned = true
                root.warnBeep()
            }
            if (root.remainingMs === 0) root.mode = "done"
        }
    }

    // Horloge affichée en haut à droite.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    // Une fenêtre plein écran par moniteur (écran + vidéoprojecteur).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property bool primary:
                Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name
                                        : modelData === Quickshell.screens[0]
            readonly property real u: height / 100   // unité : 1 % de la hauteur

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "minuteur"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            color: root.mode === "done" ? "#140003" : "#020803"
            Behavior on color { ColorAnimation { duration: 400 } }

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: true

                // Le champ de saisie disparaît au démarrage : on rend le clavier à ce gestionnaire.
                Connections {
                    target: root
                    function onModeChanged() {
                        if (root.mode !== "input") keyHandler.forceActiveFocus()
                    }
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) root.quit()
                    else if (root.mode === "running" && event.key === Qt.Key_Space) root.togglePause()
                    else if (root.mode !== "input" && event.key === Qt.Key_R) root.start(root.totalMinutes)
                    else return
                    event.accepted = true
                }

                // ---- Contenu (avec halo lumineux façon phosphore) ----
                Item {
                    id: content
                    anchors.fill: parent

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: root.accent
                        shadowBlur: 1.0
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        blurMax: 48
                    }

                    // -- Barre d'état en haut --
                    Text {
                        anchors { top: parent.top; left: parent.left; margins: win.u * 3 }
                        font.family: root.mono
                        font.pixelSize: win.u * 3
                        color: root.accent
                        opacity: 0.7
                        text: "minuteur@salle-info:~ "
                            + (root.mode === "input" ? "[ READY ]"
                             : root.mode === "done" ? "[ EXIT 0 ]"
                             : root.paused ? "[ PAUSED ]"
                             : "[ RUNNING ]")
                    }
                    Text {
                        anchors { top: parent.top; right: parent.right; margins: win.u * 3 }
                        font.family: root.mono
                        font.pixelSize: win.u * 3
                        color: root.accent
                        opacity: 0.7
                        text: Qt.formatTime(root.now, "HH:mm:ss")
                    }

                    // -- Saisie du nombre de minutes --
                    Column {
                        visible: root.mode === "input"
                        anchors.centerIn: parent
                        spacing: win.u * 4

                        Text {
                            font.family: root.mono
                            font.pixelSize: win.u * 3.5
                            color: root.green
                            opacity: 0.6
                            text: "# Durée du minuteur, en minutes :"
                        }

                        Row {
                            spacing: win.u * 3
                            Text {
                                font.family: root.mono
                                font.pixelSize: win.u * 12
                                color: root.green
                                text: "$ ./minuteur -m"
                            }
                            TextInput {
                                id: minutesInput
                                width: win.u * 25
                                font.family: root.mono
                                font.pixelSize: win.u * 12
                                font.bold: true
                                color: root.green
                                selectionColor: root.green
                                selectedTextColor: "#020803"
                                validator: IntValidator { bottom: 1; top: 999 }
                                focus: root.mode === "input" && win.primary
                                text: lastDuration.text().trim()
                                Component.onCompleted: selectAll()   // taper un nombre remplace la valeur proposée
                                onAccepted: if (acceptableInput) root.start(parseInt(text))
                                Keys.onEscapePressed: root.quit()

                                // Curseur bloc clignotant
                                cursorDelegate: Rectangle {
                                    width: win.u * 6
                                    color: root.green
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 1; duration: 0 }
                                        PauseAnimation { duration: 500 }
                                        NumberAnimation { to: 0; duration: 0 }
                                        PauseAnimation { duration: 500 }
                                    }
                                }
                            }
                        }

                        Text {
                            font.family: root.mono
                            font.pixelSize: win.u * 2.5
                            color: root.green
                            opacity: 0.5
                            text: "[Entrée] exécuter   [Échap] quitter"
                        }
                    }

                    // -- Décompte --
                    Text {
                        visible: root.mode === "running"
                        anchors.fill: parent
                        anchors.topMargin: win.u * 10
                        anchors.bottomMargin: win.u * 20      // place pour la progression et l'ETA
                        anchors.leftMargin: win.width * 0.03
                        anchors.rightMargin: win.width * 0.03
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: root.display
                        color: root.accent
                        opacity: root.paused ? 0.35 : 1
                        font.family: root.mono
                        font.bold: true
                        font.pixelSize: 2000        // réduit automatiquement par fontSizeMode
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 10
                    }

                    Column {
                        visible: root.mode === "running"
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: win.u * 5 }
                        spacing: win.u * 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: root.mono
                            font.pixelSize: win.u * 3.5
                            color: root.accent
                            opacity: 0.8
                            text: root.progressBar(40)
                        }
                        // Heure de fin, remplacée par l'indication de pause quand le décompte est suspendu
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: root.mono
                            font.pixelSize: win.u * (root.paused ? 4 : 7)
                            color: root.accent
                            text: root.paused ? "SIGSTOP reçu — [Espace] pour SIGCONT"
                                              : "ETA " + Qt.formatTime(new Date(root.endTime), "HH:mm")
                        }
                    }

                    // -- Fin --
                    Column {
                        visible: root.mode === "done"
                        anchors.centerIn: parent
                        width: parent.width * 0.92
                        spacing: win.u * 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: root.mono
                            font.pixelSize: win.u * 4
                            color: root.red
                            opacity: 0.8
                            text: "> SIGALRM reçu : temps écoulé"
                        }

                        Text {
                            width: parent.width
                            height: win.u * 55
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            text: "⏰ on rend les copies !"
                            color: root.red
                            font.family: root.mono
                            font.bold: true
                            font.pixelSize: 2000
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 10

                            SequentialAnimation on opacity {
                                running: root.mode === "done"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 700 }
                                NumberAnimation { to: 1; duration: 700 }
                            }
                        }
                    }
                }

                // ---- Lignes de balayage CRT (par-dessus, sans halo) ----
                Column {
                    anchors.fill: parent
                    Repeater {
                        model: Math.ceil(win.height / 4)
                        Item {
                            width: win.width
                            height: 4
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "black"
                                opacity: 0.35
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.mode === "done"
                    onClicked: root.quit()
                }
            }
        }
    }
}

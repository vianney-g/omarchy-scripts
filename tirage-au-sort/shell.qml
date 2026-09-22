//@ pragma AppId org.tirage-au-sort
// Tirage au sort d'un élève, pour vidéoprojecteur — style terminal à phosphore.
// Fenêtre Hyprland normale : SUPER + F bascule plein écran / fenêtré.
// Lancement : omarchy-launch-or-focus org.tirage-au-sort "uwsm-app -- qs -n -c tirage-au-sort"
//   (raccourci SUPER + ALT + T : lance l'outil, ou lui donne le focus s'il est déjà ouvert)
//
// Les classes sont lues dans ~/.config/tirage-au-sort/ : un fichier <classe>.txt
// par classe, un élève par ligne (lignes vides et lignes commençant par # ignorées).
//
//   Choix de la classe : ↑/↓ (ou j/k) puis Entrée, ou directement le chiffre
//   Tirage             : Entrée/Espace = tirer un élève, C = changer de classe
//
// Tirage sans remise : chacun passe une fois avant qu'un nouveau tour commence.
// L'état de chaque classe (déjà passés, historique) est conservé jusqu'à la fermeture.
//   Partout            : Q = quitter (Échap ne quitte pas, pour ne pas perdre la classe par réflexe)
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // "loading" -> "select" -> "draw"
    property string mode: "loading"
    property var classes: []          // [{ name, students: [...] }]
    property int selected: 0
    property var currentClass: null

    property string shown: ""         // nom affiché
    property bool rolling: false      // animation de défilement en cours
    property string pick: ""          // nom tiré, révélé à la fin de l'animation

    // État de la classe en cours (sauvegardé dans « sessions » quand on change de classe)
    property var drawn: []            // élèves déjà passés pendant ce tour
    property var history: []          // derniers tirés, le plus récent en premier
    property int drawCount: 0
    property int round: 1
    property var sessions: ({})       // { <classe>: { drawn, history, drawCount, round } }

    // Élèves pas encore passés. Calculé depuis le fichier : un nom ajouté ou retiré est pris en compte.
    readonly property var remaining:
        currentClass ? currentClass.students.filter(s => !drawn.includes(s)) : []
    property int rollStep: 0
    readonly property int rollSteps: 14   // ~0,9 s au total (voir rollTimer)

    property date now: new Date()

    readonly property color green: "#33ff66"
    readonly property color amber: "#ffb000"
    readonly property color red: "#ff3344"
    readonly property string mono: "JetBrainsMono Nerd Font"

    readonly property string configDir:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/tirage-au-sort"
    readonly property string configDirShort: configDir.replace(Quickshell.env("HOME"), "~")
    readonly property bool emptyClass:
        mode === "draw" && currentClass !== null && currentClass.students.length === 0

    function plural(n) { return n + (n > 1 ? " élèves" : " élève") }

    // --- Lecture des classes ---
    // Chaque fichier est précédé d'une ligne « \x1f<classe> » pour les séparer.
    Process {
        id: loader
        command: ["sh", "-c",
            'cd "$1" 2>/dev/null || exit 0; for f in *.txt; do [ -f "$f" ] || continue; printf "\\037%s\\n" "${f%.txt}"; cat "$f"; echo; done',
            "sh", root.configDir]
        stdout: StdioCollector {
            onStreamFinished: root.parseClasses(this.text)
        }
    }

    function reload() {
        saveSession()
        mode = "loading"
        loader.running = true
    }

    function parseClasses(text) {
        const result = []
        for (const raw of text.split("\n")) {
            if (raw.startsWith("\x1f")) {
                result.push({ name: raw.slice(1), students: [] })
                continue
            }
            const line = raw.trim()
            if (line === "" || line.startsWith("#") || result.length === 0) continue
            result[result.length - 1].students.push(line)
        }
        result.sort((a, b) => a.name.localeCompare(b.name, "fr", { numeric: true }))
        classes = result
        selected = Math.min(selected, Math.max(0, result.length - 1))
        mode = "select"
    }

    function saveSession() {
        if (!currentClass) return
        const copy = Object.assign({}, sessions)
        copy[currentClass.name] = { drawn: drawn, history: history, drawCount: drawCount, round: round }
        sessions = copy
    }

    function chooseClass(index) {
        if (index < 0 || index >= classes.length) return
        selected = index
        currentClass = classes[index]
        const saved = sessions[currentClass.name]
        drawn = saved ? saved.drawn : []
        history = saved ? saved.history : []
        drawCount = saved ? saved.drawCount : 0
        round = saved ? saved.round : 1
        shown = history.length > 0 ? history[0] : ""
        mode = "draw"
    }

    function randomOf(list) {
        return list[Math.floor(Math.random() * list.length)]
    }

    // Nom affiché pendant le défilement : n'importe quel élève, différent du précédent.
    function rollingName() {
        const s = currentClass.students
        if (s.length < 2) return s[0]
        let name
        do { name = randomOf(s) } while (name === shown)
        return name
    }

    function draw() {
        if (rolling || !currentClass || currentClass.students.length === 0) return

        // Tout le monde est passé : nouveau tour.
        let pool = remaining
        if (pool.length === 0) {
            drawn = []
            round++
            pool = currentClass.students
        }
        // Évite que le dernier tiré ouvre aussi le nouveau tour.
        const candidates = pool.length > 1 ? pool.filter(s => s !== history[0]) : pool
        pick = randomOf(candidates)

        rollStep = 0
        rolling = true
        rollTimer.interval = 20
        rollTimer.start()
    }

    // Défilement qui ralentit progressivement avant de s'arrêter sur le nom tiré.
    // Durée totale : 20 + Σ(20 + 0,75·k²) pour k = 1..13 ≈ 0,9 s.
    Timer {
        id: rollTimer
        repeat: true
        onTriggered: {
            root.rollStep++
            interval = 20 + root.rollStep * root.rollStep * 0.75
            if (root.rollStep < root.rollSteps) {
                root.shown = root.rollingName()
                return
            }
            stop()
            root.shown = root.pick
            root.drawn = root.drawn.concat([root.pick])
            root.history = [root.pick].concat(root.history).slice(0, 5)
            root.drawCount++
            root.rolling = false
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Component.onCompleted: reload()

    FloatingWindow {
        id: win
        title: "Tirage au sort" + (root.mode === "draw" ? " — " + root.currentClass.name : "")
        implicitWidth: 1400
        implicitHeight: 700
        color: "#020803"

        // Unité de taille : 1 % de la hauteur, bornée par la largeur pour les fenêtres étroites.
        readonly property real u: Math.min(height, width * 0.5) / 100

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()

            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Q) Qt.quit()
                else if (root.mode === "select") {
                    if (k === Qt.Key_Down || k === Qt.Key_J)
                        root.selected = Math.min(root.selected + 1, root.classes.length - 1)
                    else if (k === Qt.Key_Up || k === Qt.Key_K)
                        root.selected = Math.max(root.selected - 1, 0)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                        root.chooseClass(root.selected)
                    else if (k >= Qt.Key_1 && k <= Qt.Key_9)
                        root.chooseClass(k - Qt.Key_1)
                    else return
                }
                else if (root.mode === "draw") {
                    if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.draw()
                    else if (k === Qt.Key_C) root.reload()   // relit les fichiers au passage
                    else return
                }
                else return
                event.accepted = true
            }

            // ---- Contenu (avec halo lumineux façon phosphore) ----
            Item {
                anchors.fill: parent

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.emptyClass ? root.red : root.green
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
                    color: root.green
                    opacity: 0.7
                    text: "tirage@salle-info:~ "
                        + (root.mode === "draw" ? "[ " + root.currentClass.name + " · "
                                                  + root.plural(root.currentClass.students.length) + " ]"
                                                : "[ READY ]")
                }
                Text {
                    anchors { top: parent.top; right: parent.right; margins: win.u * 3 }
                    font.family: root.mono
                    font.pixelSize: win.u * 3
                    color: root.green
                    opacity: 0.7
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                }

                // -- Choix de la classe --
                Column {
                    visible: root.mode === "select"
                    anchors.centerIn: parent
                    spacing: win.u * 2.5

                    Text {
                        font.family: root.mono
                        font.pixelSize: win.u * 3.5
                        color: root.green
                        opacity: 0.6
                        text: root.classes.length > 0 ? "# Choisir une classe :"
                                                      : "# Aucune classe trouvée dans " + root.configDirShort
                    }
                    Text {
                        font.family: root.mono
                        font.pixelSize: win.u * 8
                        color: root.green
                        text: "$ ls classes/"
                    }

                    Repeater {
                        model: root.classes
                        Text {
                            required property var modelData
                            required property int index
                            readonly property bool current: index === root.selected
                            font.family: root.mono
                            font.pixelSize: win.u * 6
                            font.bold: current
                            color: modelData.students.length === 0 ? root.red : root.green
                            opacity: current ? 1 : 0.5
                            text: (current ? "> " : "  ") + "[" + (index + 1) + "] "
                                + modelData.name.padEnd(6, " ")
                                + (modelData.students.length === 0 ? "(vide)"
                                   : "(" + root.plural(modelData.students.length) + ")")
                        }
                    }

                    Text {
                        font.family: root.mono
                        font.pixelSize: win.u * 2.5
                        color: root.green
                        opacity: 0.5
                        text: root.classes.length > 0
                              ? "[↑↓] naviguer   [Entrée] ou [1-9] choisir   [Q] quitter"
                              : "Créez un fichier <classe>.txt par classe, un élève par ligne."
                    }
                }

                // -- Tirage --
                Text {
                    visible: root.mode === "draw"
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: win.u * 16 }
                    font.family: root.mono
                    font.pixelSize: win.u * 4
                    color: root.green
                    opacity: 0.6
                    text: "$ shuf -n1 " + (root.currentClass ? root.currentClass.name : "") + ".txt"
                }

                Text {
                    visible: root.mode === "draw"
                    anchors.fill: parent
                    anchors.topMargin: win.u * 24
                    anchors.bottomMargin: win.u * 28
                    anchors.leftMargin: win.width * 0.04
                    anchors.rightMargin: win.width * 0.04
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    font.family: root.mono
                    font.bold: !root.rolling
                    font.pixelSize: win.u * 22        // taille maximale, réduite si le nom est long
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 10
                    color: root.emptyClass ? root.red
                         : root.rolling ? root.amber : root.green
                    opacity: root.rolling ? 0.7 : 1
                    text: root.emptyClass
                          ? "classe vide"
                          : root.shown !== "" ? root.shown : "_"
                }

                // Historique des derniers tirés (hors nom affiché)
                Text {
                    visible: root.mode === "draw" && root.history.length > 1
                    width: parent.width * 0.9
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: win.u * 19 }
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: root.mono
                    font.pixelSize: win.u * 3.5
                    color: root.green
                    opacity: 0.45
                    text: "$ history | tail : " + root.history.slice(1).join(" · ")
                }

                Text {
                    visible: root.mode === "draw"
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: win.u * 12 }
                    font.family: root.mono
                    font.pixelSize: win.u * 3.5
                    color: root.green
                    opacity: 0.6
                    text: root.rolling ? "# random.choice() en cours…"
                        : root.drawCount > 0
                          ? "# tirage n°" + root.drawCount
                            + (root.round > 1 ? " · tour " + root.round : "")
                            + (root.remaining.length === 0
                               ? " · tout le monde est passé, le prochain tirage relance un tour"
                               : " · reste " + root.remaining.length + "/" + root.currentClass.students.length)
                        : root.emptyClass
                          ? "# ajoutez des noms dans " + root.configDirShort + "/" + root.currentClass.name + ".txt"
                        : "# prêt"
                }

                Text {
                    visible: root.mode === "draw"
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: win.u * 5 }
                    font.family: root.mono
                    font.pixelSize: win.u * 2.5
                    color: root.green
                    opacity: 0.5
                    text: "[Entrée] ou [Espace] tirer   [C] changer de classe   [Q] quitter"
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
        }
    }
}

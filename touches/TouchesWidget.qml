import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Chip de la barre : allumé tant que les frappes sont affichées.
// Toute la logique vit dans le service ; ce widget n'est qu'une vue.
BarWidget {
    id: root
    moduleName: "vianney.touches"

    property var engine: null
    property int resolveAttempts: 0

    readonly property bool showing: engine ? engine.enabled === true : false

    implicitWidth: engine ? button.implicitWidth : 0
    implicitHeight: engine ? button.implicitHeight : 0
    visible: engine !== null

    function resolveEngine() {
        const host = bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell : null
        if (host) engine = host.serviceFor("vianney.touches")
    }

    Component.onCompleted: resolveEngine()

    // Le service peut être monté après la barre : on réessaie quelques secondes.
    Timer {
        interval: 1000
        repeat: true
        running: root.engine === null && root.resolveAttempts < 30
        onTriggered: {
            root.resolveAttempts++
            root.resolveEngine()
        }
    }

    BarIconButton {
        id: button
        bar: root.bar
        text: "󰌌"
        active: root.showing
        tooltipText: root.showing
            ? "Touches affichées — attention aux mots de passe · cliquer pour arrêter"
            : "Afficher les touches frappées (démonstration en classe)"
        onPressed: if (root.engine) root.engine.setEnabled(!root.showing)
    }
}

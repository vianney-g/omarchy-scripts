# Touches

Plugin [Omarchy](https://omarchy.org/) qui affiche les touches et raccourcis
frappés, dans un bandeau en bas de l'écran. Pensé pour la démonstration en
classe : les élèves voient les raccourcis au lieu de subir des fenêtres qui
changent toutes seules.

## Crédit

Le mécanisme de capture est repris de
[community.keycast](https://github.com/devmobasa/omarchy-keycast) de devmobasa
(MIT) : voir [LICENSE-keycast](LICENSE-keycast). Les libellés par disposition
clavier, la réduction en accords et l'apparence sont réécrits ici.

## Fonctionnement

Hyprland 0.56 expose un événement `input.keyboard.key` sur son bus Lua. À
l'activation, un handler d'une ligne enregistré via `hyprctl repl` republie
chaque événement en événement socket2 que le shell consomme. **Aucun accès à
`/dev/input`, aucun démon, aucun privilège.** À la désactivation le handler est
retiré : le compositeur ne fait plus rien par touche. Les frappes ne sont
jamais écrites sur disque, elles n'existent qu'en mémoire et à l'écran.

## Abonnement Lua : un seul, toujours

L'abonnement vit dans Hyprland, pas dans le shell : il survit au redémarrage du
shell. Réassigner la variable Lua `TOUCHES_SUB` ne supprimerait pas l'ancien
abonnement, qui continuerait d'émettre — chaque frappe serait alors comptée
deux fois, trois fois… Le handler retire donc toujours l'abonnement existant
avant d'en créer un. En complément, deux événements identiques séparés de moins
de 8 ms sont considérés comme un doublon et non comme une double frappe.

Un abonnement orphelin n'est pas récupérable depuis Lua (Hyprland le retient
côté C++) et survit jusqu'à la fermeture de session. Chaque enregistrement
porte donc une **signature unique** : le service n'écoute que les événements
de la sienne, et un orphelin devient inaudible.

## Hyprland livre chaque événement deux fois

Mesuré sur Hyprland 0.56.2 : le handler est appelé **deux fois pour un même
événement**, les deux copies portant le même horodatage compositeur. L'ordre
varie selon la touche — `appui, appui, relâché, relâché` pour une touche
ordinaire, mais `appui, relâché, appui, relâché` pour une touche à *home row
mod*, où la copie arrive après le relâchement.

Aucun filtre temporel ne distingue ce second cas d'une double frappe. Le
handler transporte donc l'horodatage de l'événement, et le service écarte tout
triplet `code:horodatage:état` déjà vu : exact, sans heuristique.

## Libellés et disposition clavier

L'événement ne transporte qu'un code de touche physique. Les libellés sont donc
générés depuis les dispositions réelles avec `xkbcli`, et le plugin choisit la
table d'après la disposition active (bépo, azerty, qwerty), en suivant les
changements en cours de route.

```bash
./tools/gen-labels.py > model/Labels.js   # à relancer pour ajouter une disposition
```

## Attention aux mots de passe

Tant que l'affichage est actif, **tout ce que vous tapez apparaît à l'écran**,
y compris dans une invite de mot de passe. Désactivez-le avant de saisir un
secret.

## Installation

```bash
ln -s "$PWD/touches" ~/.config/omarchy/plugins/vianney.touches
omarchy plugin enable vianney.touches
```

Activation par l'icône clavier dans la barre, par IPC, ou par un raccourci :

```bash
omarchy-shell vianney.touches toggle | enable | disable | status
```

```lua
o.bind("SUPER + ALT + C", "Touches à l'écran", "omarchy-shell vianney.touches toggle")
```

# omarchy-scripts

Mes scripts et petits outils personnels pour [Omarchy](https://omarchy.org/).

## minuteur

Minuteur plein écran en [Quickshell](https://quickshell.org/), pensé pour être
projeté en classe. Style terminal à phosphore.

- Saisie du nombre de minutes (la dernière durée est pré-remplie).
- Décompte `MM:SS` géant, barre de progression et heure de fin (`ETA`).
- À 5 minutes de la fin : passage en ambre et bip discret ; dernière minute en rouge.
- À la fin : « ⏰ on rend les copies ! » et sonnerie de réveil.
- Le mode « stay awake » d'Omarchy est activé pendant le décompte, puis remis
  dans son état initial.
- Affiché sur tous les écrans (écran du portable + vidéoprojecteur).
- Pilotable depuis le téléphone (voir [télécommande](#télécommande-depuis-le-téléphone)).

| Touche | Action |
|--------|--------|
| `Entrée` | démarrer |
| `Espace` | pause / reprise |
| `R` | recommencer avec la même durée |
| `Échap` | quitter |

### Installation

```bash
ln -s "$PWD/minuteur" ~/.config/quickshell/minuteur
```

Puis ajouter le raccourci dans `~/.config/hypr/bindings.lua` :

```lua
o.bind("SUPER + ALT + M", "Minuteur", "qs -n -c minuteur")
```

Dépendances : `quickshell`, `pipewire` (`pw-play`), `sound-theme-freedesktop`,
police JetBrainsMono Nerd Font — tous présents sur une installation Omarchy standard.

## tirage-au-sort

Tirage au sort d'un élève en [Quickshell](https://quickshell.org/), même style
terminal que le minuteur.

- Choix de la classe dans une liste, puis tirage avec une animation de défilement (< 1 s).
- Tirage sans remise : chaque élève passe une fois avant qu'un nouveau tour commence
  (`reste 12/25`, `tour 2`). Un élève absent ? On relance simplement un tirage.
- Historique des 4 derniers tirés sous le nom affiché.
- L'état de chaque classe (tour en cours, élèves déjà passés, historique) est
  enregistré : on le retrouve au lancement suivant. Remise à zéro par
  `Ctrl + Maj + R`, un raccourci volontairement peu accessible.
- Fenêtre Hyprland normale, pensée pour rester ouverte tout le cours sur la même
  classe : le raccourci la lance, ou lui redonne le focus si elle est déjà ouverte.
  Elle s'ouvre en plein écran (règle de fenêtre ci-dessous) ; `SUPER + F` bascule
  plein écran / fenêtré.
- Les classes sont de simples fichiers texte, **hors du repo** : aucun nom
  d'élève n'est versionné.
- Pilotable depuis le téléphone (voir [télécommande](#télécommande-depuis-le-téléphone)).

| Touche | Action |
|--------|--------|
| `↑` `↓` (ou `j` `k`), `Entrée` | choisir la classe |
| `1` … `9` | choisir directement la classe n° |
| `Entrée` / `Espace` | tirer un élève |
| `C` | changer de classe (relit les fichiers) |
| `Ctrl` + `Maj` + `R` | remettre à zéro le tour de la classe affichée |
| `Q` | quitter (Échap ne quitte pas, pour ne pas perdre la classe par réflexe) |

### Configuration des classes

Un fichier `<classe>.txt` par classe dans `~/.config/tirage-au-sort/`, un élève
par ligne. Les lignes vides et celles qui commencent par `#` sont ignorées. Le
nom du fichier donne le nom de la classe (`L1.txt` → « L1 »).

```bash
mkdir -p ~/.config/tirage-au-sort
cp tirage-au-sort/exemple/*.txt ~/.config/tirage-au-sort/   # puis éditer
```

L'état des tirages est enregistré à part, dans
`~/.local/state/quickshell/by-shell/<id>/sessions.json`. Ce fichier contient des
noms d'élèves : il reste sur la machine et n'a pas sa place dans un dépôt.

### Installation

```bash
ln -s "$PWD/tirage-au-sort" ~/.config/quickshell/tirage-au-sort
```

Puis dans `~/.config/hypr/bindings.lua` :

```lua
o.bind("SUPER + ALT + T", "Tirage au sort",
	'omarchy-launch-or-focus org.tirage-au-sort "uwsm-app -- qs -n -c tirage-au-sort"')
```

Et, pour l'ouvrir en plein écran, dans `~/.config/hypr/hyprland.lua` :

```lua
o.window("^org\\.tirage-au-sort$", { fullscreen = true })
```

## touches

Plugin Omarchy qui affiche les touches et raccourcis frappés, en bas de l'écran,
pour la démonstration en classe. Activable par l'icône clavier de la barre ou
par `SUPER + ALT + C`. Sans accès à `/dev/input` ni privilège : il s'abonne à
l'événement clavier du bus Lua d'Hyprland 0.56.

Libellés générés depuis vos vraies dispositions clavier (bépo, azerty, qwerty)
et suivis en cours de session. Voir [touches/README.md](touches/README.md) —
mécanisme dérivé de [community.keycast](https://github.com/devmobasa/omarchy-keycast) (MIT).

## Télécommande depuis le téléphone

Le script [`telecommande/cours`](telecommande/cours) lance les outils et les pilote
par l'IPC de Quickshell. Branché sur les boutons « Exécuter une commande » de
[KDE Connect](https://kdeconnect.kde.org/), il transforme le téléphone en télécommande.

| Commande | Effet |
|----------|-------|
| `cours minuteur 10` | lance le minuteur si besoin et démarre 10 min |
| `cours minuteur pause` | pause / reprise |
| `cours minuteur restart` | recommence avec la même durée |
| `cours minuteur quit` | quitte |
| `cours tirage L1` | ouvre le tirage au sort sur la classe L1 (ou le met au premier plan) |
| `cours tirage draw` | tire un élève |
| `cours tirage quit` | quitte (l'état est enregistré) |
| `cours touches` | affiche / masque les touches à l'écran |

La remise à zéro d'une classe n'est volontairement pas accessible à distance.
En cas d'erreur (outil pas lancé, classe inconnue…), une notification s'affiche.

### Installation

```bash
ln -s "$PWD/telecommande/cours" ~/.local/bin/cours
omarchy pkg add kdeconnect
sudo ufw allow 1714:1764/tcp
sudo ufw allow 1714:1764/udp
```

Démarrer le démon à l'ouverture de session, dans `~/.config/hypr/autostart.lua` :

```lua
o.launch_on_start("kdeconnectd")
```

Installer l'application KDE Connect sur le téléphone, appairer les deux appareils
(`kdeconnect-app` côté PC), puis déclarer les commandes dans
`kdeconnect-settings` → téléphone → *Exécuter une commande*. Utiliser le chemin
complet (`~/.local/bin/cours minuteur 10`…) : le démon n'a pas forcément
`~/.local/bin` dans son `PATH`.

**Réseau** : beaucoup de Wi-Fi d'établissement (eduroam…) isolent les appareils
entre eux, et le téléphone ne voit alors pas le PC. Dans ce cas, activer le
partage de connexion du téléphone et y connecter le PC.

## Licence

[MIT](LICENSE)

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
- L'état de chaque classe est conservé jusqu'à la fermeture, même en changeant de classe.
- Fenêtre Hyprland normale, pensée pour rester ouverte tout le cours sur la même
  classe : le raccourci la lance, ou lui redonne le focus si elle est déjà ouverte ;
  `SUPER + F` bascule plein écran / fenêtré.
- Les classes sont de simples fichiers texte, **hors du repo** : aucun nom
  d'élève n'est versionné.

| Touche | Action |
|--------|--------|
| `↑` `↓` (ou `j` `k`), `Entrée` | choisir la classe |
| `1` … `9` | choisir directement la classe n° |
| `Entrée` / `Espace` | tirer un élève |
| `C` | changer de classe (relit les fichiers) |
| `Q` | quitter (Échap ne quitte pas, pour ne pas perdre la classe par réflexe) |

### Configuration des classes

Un fichier `<classe>.txt` par classe dans `~/.config/tirage-au-sort/`, un élève
par ligne. Les lignes vides et celles qui commencent par `#` sont ignorées. Le
nom du fichier donne le nom de la classe (`L1.txt` → « L1 »).

```bash
mkdir -p ~/.config/tirage-au-sort
cp tirage-au-sort/exemple/*.txt ~/.config/tirage-au-sort/   # puis éditer
```

### Installation

```bash
ln -s "$PWD/tirage-au-sort" ~/.config/quickshell/tirage-au-sort
```

Puis dans `~/.config/hypr/bindings.lua` :

```lua
o.bind("SUPER + ALT + T", "Tirage au sort",
	'omarchy-launch-or-focus org.tirage-au-sort "uwsm-app -- qs -n -c tirage-au-sort"')
```

## Licence

[MIT](LICENSE)

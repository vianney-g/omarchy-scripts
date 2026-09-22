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

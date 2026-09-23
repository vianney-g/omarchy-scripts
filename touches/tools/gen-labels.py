#!/usr/bin/env python3
"""Génère model/Labels.js : code evdev -> libellé, pour chaque disposition.

L'événement clavier d'Hyprland ne transporte qu'un code de touche physique.
Pour afficher « É » quand on appuie sur É en bépo (et « P » en QWERTY, au même
endroit), on compile chaque disposition avec xkbcli et on lit le symbole de
niveau 1 de chaque touche. Les noms de symboles (« ecircumflex », « bar »…)
sont traduits en caractères via keysymdef.h.

Usage : ./tools/gen-labels.py > model/Labels.js
"""
import json
import re
import subprocess

# Dispositions générées. La clé est celle utilisée par le plugin à l'exécution.
LAYOUTS = {
    "bepo": ("fr", "bepo"),
    "azerty": ("fr", "azerty"),
    "qwerty": ("us", ""),
}

# Touches sans caractère imprimable : libellé fixe, plus lisible qu'un symbole.
SPECIAL = {
    "Return": "⏎", "KP_Enter": "⏎", "BackSpace": "⌫", "Tab": "⇥",
    "Escape": "Échap", "space": "Espace", "Delete": "Suppr", "Insert": "Inser",
    "Home": "Début", "End": "Fin", "Prior": "PgPréc", "Next": "PgSuiv",
    "Up": "↑", "Down": "↓", "Left": "←", "Right": "→",
    "Caps_Lock": "Verr.Maj", "Num_Lock": "Verr.Num", "Scroll_Lock": "Arrêt défil",
    "Print": "Impr", "Pause": "Pause", "Menu": "Menu",
    "ISO_Level3_Shift": "AltGr", "ISO_Level5_Shift": "AltFr",
}
SPECIAL.update({f"F{i}": f"F{i}" for i in range(1, 25)})

# Modificateurs : reconnus par leur code evdev, hors dispositions.
MODIFIERS = {
    29: "Ctrl", 97: "Ctrl", 42: "Maj", 54: "Maj",
    56: "Alt", 100: "AltGr", 125: "Super", 126: "Super",
}


def keysym_chars():
    """Nom de keysym -> caractère, d'après keysymdef.h."""
    out = {}
    pattern = re.compile(r"#define XK_(\w+)\s+0x[0-9a-fA-F]+\s*/\*[ (]*U\+([0-9A-Fa-f]{4,6})")
    with open("/usr/include/X11/keysymdef.h", encoding="latin-1") as f:
        for line in f:
            m = pattern.match(line)
            if m:
                out.setdefault(m.group(1), chr(int(m.group(2), 16)))
    return out


def labels_for(layout, variant, chars):
    cmd = ["xkbcli", "compile-keymap", "--layout", layout]
    if variant:
        cmd += ["--variant", variant]
    keymap = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

    # xkb_keycodes : <AD01> = 24;  (code xkb = code evdev + 8)
    names = {m.group(1): int(m.group(2)) - 8
             for m in re.finditer(r"<(\w+)>\s*=\s*(\d+);", keymap)}
    # xkb_symbols : key <AD01> { [ b, B, bar, brokenbar ] };
    result = {}
    for m in re.finditer(r"key <(\w+)>\s*\{\s*\[([^\]]*)\]", keymap):
        code = names.get(m.group(1))
        if code is None or code in MODIFIERS:
            continue
        sym = m.group(2).split(",")[0].strip()
        if sym in ("NoSymbol", "VoidSymbol", ""):
            continue
        label = SPECIAL.get(sym) or chars.get(sym)
        if label is None:
            continue
        result[code] = label.upper() if len(label) == 1 and label.isalpha() else label
    return result


def main():
    chars = keysym_chars()
    maps = {key: labels_for(*spec, chars) for key, spec in LAYOUTS.items()}
    print("// Généré par tools/gen-labels.py — ne pas éditer à la main.")
    print("// Code evdev -> libellé affiché, pour chaque disposition clavier.")
    print("var MODIFIERS = %s" % json.dumps(MODIFIERS, ensure_ascii=False, sort_keys=True))
    print("var LAYOUTS = %s" % json.dumps(maps, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()

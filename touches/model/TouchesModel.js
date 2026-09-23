// Réduction du flux de touches en « accords » affichables.
// Sans dépendance : ce fichier est chargé par QML et testable avec node.
//
// Source : l'événement Lua « input.keyboard.key » d'Hyprland 0.56, republié
// en événement socket2 par un handler d'une ligne (voir REGISTER_LUA).
// Rien n'est jamais écrit sur disque : les frappes vivent en mémoire et à l'écran.
.import "Labels.js" as Labels

// Le handler reste court : les callbacks Lua tournent sur le thread du
// compositeur, sous surveillance d'un chien de garde.
var REGISTER_LUA = 'TOUCHES_SUB = hl.on("input.keyboard.key", function(kc, t, state) '
  + 'hl.dispatch(hl.dsp.event("touches," .. kc .. "," .. state)) end)'
var UNREGISTER_LUA = 'if TOUCHES_SUB then TOUCHES_SUB:remove() TOUCHES_SUB = nil end'

var MAX_ENTRIES = 6

// « touches,<code xkb>,<état> » — état 1 = appui, 0 = relâchement.
function parseEvent(data) {
  var parts = String(data == null ? "" : data).split(",")
  if (parts.length !== 3 || parts[0] !== "touches") return null
  var keycode = Number(parts[1])
  if (!isFinite(keycode) || keycode <= 8 || keycode !== Math.floor(keycode)) return null
  if (parts[2] !== "0" && parts[2] !== "1") return null
  return { code: keycode - 8, pressed: parts[2] === "1" }
}

// Nom de disposition d'après le keymap actif rapporté par Hyprland.
function layoutKey(activeKeymap) {
  var name = String(activeKeymap || "").toLowerCase()
  if (name.indexOf("bepo") >= 0) return "bepo"
  if (name.indexOf("azerty") >= 0 || name.indexOf("french") >= 0) return "azerty"
  return "qwerty"
}

function modifierName(code) {
  return Labels.MODIFIERS[code] || ""
}

function keyLabel(code, layout) {
  var map = Labels.LAYOUTS[layout] || Labels.LAYOUTS.qwerty
  return map[code] || ("#" + code)
}

function emptyState() {
  return { mods: [], held: [], modUsed: false, entries: [] }
}

function entryLabel(entry) {
  var text = entry.mods.length > 0 ? entry.mods.join(" + ") + " + " + entry.label : entry.label
  return entry.count > 1 ? text + " ×" + entry.count : text
}

function signature(entry) {
  return entry.mods.join("+") + "|" + entry.label
}

function push(entries, entry) {
  var next = entries.slice()
  var last = next.length > 0 ? next[next.length - 1] : null
  if (last && signature(last) === signature(entry)) {
    next[next.length - 1] = { mods: last.mods, label: last.label, count: last.count + 1 }
    return next
  }
  next.push(entry)
  return next.slice(Math.max(0, next.length - MAX_ENTRIES))
}

// Renvoie toujours un nouvel état : QML ne réagit qu'aux réaffectations.
function applyEvent(state, event, layout) {
  var mods = state.mods.slice()
  var held = state.held.slice()
  var modUsed = state.modUsed
  var entries = state.entries
  var mod = modifierName(event.code)

  if (mod !== "") {
    if (event.pressed) {
      if (mods.indexOf(mod) < 0) mods.push(mod)
      // « held » garde la combinaison la plus large tenue depuis le dernier relâchement.
      if (mods.length > held.length) held = mods.slice()
      modUsed = false
    } else {
      mods.splice(mods.indexOf(mod), 1)
      // Modificateurs appuyés seuls (Super pour le menu, par exemple) : on les affiche.
      if (mods.length === 0) {
        if (!modUsed) entries = push(entries, { mods: [], label: held.join(" + "), count: 1 })
        held = []
      }
    }
    return { mods: mods, held: held, modUsed: modUsed, entries: entries }
  }

  if (event.pressed) {
    modUsed = true
    entries = push(entries, { mods: mods, label: keyLabel(event.code, layout), count: 1 })
  }
  return { mods: mods, held: held, modUsed: modUsed, entries: entries }
}

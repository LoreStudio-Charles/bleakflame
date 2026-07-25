class_name Techniques
## THE TECHNIQUE BOOK — what a CHARACTER knows how to do (docs/ground_combat.md).
##
## THE DELIBERATE ASYMMETRY (user, 2026-07-25): a ship's abilities are CHIPS — hardware
## you fit, and unfitting the chip takes the ability with it. A character's abilities are
## TRAINING — "equipped like spells in fantasy MMORPGs": you learn them from your
## commission's leader (the ability tree is the syllabus) and they stay learned. Ship =
## hardware, character = training. Same 5-slot bus idiom, entirely separate list and save
## key, because they are different KINDS of thing.
##
## SOURCES:
##   "universal" — everybody knows it, from the first landfall. The tutorial-safe floor,
##                 so the first scrit fight works before you have joined anyone.
##   "<profession id>" — trained by that commission (Professions.LIST ids). Known once
##                 you hold that commission; the per-node standing/level gates come with
##                 the office syllabus pass.
##
## Adding a technique = ONE entry here + one dispatch arm in EpharonTown._use_technique.
## No other wiring: the bus, the prepare UI, the tooltips and the save all read this list.

const LIST := [
	# ---- THE UNIVERSAL FLOOR (pre-commission; everyone) ----
	{"id": "field_patch", "name": "Field Patch", "source": "universal",
		"energy": 25.0, "cooldown": 14.0, "heal": 34.0,
		"desc": "Slap a sealant patch over the worst of it. Mends a wound on the spot — no substitute for a berth."},
	{"id": "sand_kick", "name": "Kick Sand", "source": "universal",
		"energy": 12.0, "cooldown": 9.0, "range": 90.0, "duration": 3.0,
		"desc": "A bootful of Epharon into your target's eyes. It stops fighting and reels — brief, cheap, and it buys you the step you needed."},
	{"id": "second_wind", "name": "Second Wind", "source": "universal",
		"energy": 18.0, "cooldown": 22.0, "duration": 5.0,
		"desc": "Dig in and move. A short burst of speed — for closing a gap, or not being where the claws are."},
	# ---- PROFESSION SEAM (identity mirrors the ship kits; docs/professions.md) ----
	{"id": "brace", "name": "Brace", "source": "guardian",
		"energy": 30.0, "cooldown": 26.0, "duration": 6.0, "mitigation": 0.3,
		"desc": "Set your feet and take it. Heavy damage reduction while it holds. Guardian training."},
]

## The character's own bus. Five, like the ship's — the input scheme's [1]-[5] on foot.
const BUS_SLOTS := 5


static func def(id: String) -> Dictionary:
	for t in LIST:
		if t.id == id:
			return t
	return {}


static func display_name(id: String) -> String:
	var d := def(id)
	return str(d.get("name", id)) if not d.is_empty() else id


## Everything THIS character has been trained in: the universal floor plus their
## commission's syllabus. The book; what's on the keys is Pilot.techniques.
static func known() -> Array:
	var out: Array = []
	for t in LIST:
		var src := str(t.source)
		if src == "universal" or src == Pilot.profession:
			out.append(str(t.id))
	return out


## Drop-in art, same convention as ship abilities: assets/icons/techniques/<id>.png.
## Callers must handle null — a technique works the day it is written.
static func icon(id: String) -> Texture2D:
	var p := "res://assets/icons/techniques/%s.png" % id
	return load(p) if id != "" and ResourceLoader.exists(p) else null


## The hover body — the live numbers, so a tooltip never disagrees with the fight.
## Returns a STRING (never a Control) so this file stays UI-free and parses under
## --script, exactly like Abilities.tooltip_body.
static func tooltip_body(id: String) -> String:
	var d := def(id)
	if d.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("Energy %d" % int(d.get("energy", 0.0)) if float(d.get("energy", 0.0)) > 0.0
		else "No energy cost")
	if float(d.get("cooldown", 0.0)) > 0.0:
		lines.append("Cooldown %.0fs" % float(d.cooldown))
	if float(d.get("range", 0.0)) > 0.0:
		lines.append("Range %.0f" % float(d.range))
	if float(d.get("duration", 0.0)) > 0.0:
		lines.append("Lasts %.0fs" % float(d.duration))
	if float(d.get("heal", 0.0)) > 0.0:
		lines.append("Mends %.0f" % float(d.heal))
	if float(d.get("mitigation", 0.0)) > 0.0:
		lines.append("Mitigation +%d%%" % int(round(float(d.mitigation) * 100.0)))
	var src := str(d.source)
	var trained := "Universal training" if src == "universal" \
		else "%s training" % Professions.display_name(src)
	return "[color=#8fe08f]%s[/color]\n[i][color=#a8b0c2]%s[/color][/i]\n[color=#73bff2]%s[/color]" % [
		" · ".join(lines), str(d.get("desc", "")), trained]

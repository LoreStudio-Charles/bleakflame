class_name Abilities
## The ABILITY BOOK catalog — every player-activatable ability, keyed by a
## stable id. Abilities come from two sources: MODULES (a fitted activatable
## SystemDef, matched by `tag`) and, later, TRAINED actives from the skill tree
## (source "skill"). The player MEMORIZES known abilities into the 5 GEM slots
## (Pilot.gems); only a gemmed AND currently-available ability fires on [1]-[5].
## This is EverQuest's spellbook (all you know) vs spell gems (what's on keys).
##
## Adding a module ability = one LIST entry with its SystemDef tag; the ship
## dispatches by `id` in _activate_gem(). No other wiring.

static var _icon_cache := {}

const LIST := [
	{"id": "scan", "name": "Survey Scan", "source": "module", "tag": "scan",
		"desc": "Channel a survey on your selected target — ore inside rock, Scan Data from ships."},
	{"id": "cloak", "name": "Cloak Field", "source": "module", "tag": "cloak",
		"desc": "Bend light around the hull; hostiles lose their lock. Privateer tech."},
	{"id": "bulwark", "name": "Bulwark Brace", "source": "module", "tag": "bulwark",
		"desc": "Throw a damage-reduction field over yourself and nearby allies for a few seconds. Guardian tech — a boss-burst brace."},
	{"id": "decoy_flare", "name": "Decoy Flare", "source": "module", "tag": "decoy",
		"desc": "Break every hostile lock and eject a bright decoy that pulls their fire. Trader tech — the convoy countermeasure."},
	{"id": "jinx", "name": "JINX Evasion Protocol", "source": "module", "tag": "jinx",
		"desc": "Flood the wing with the Shoal's jink tables — allies in range fly a much smaller profile for a few seconds. Privateer tech: doesn't soak the spike, makes it miss."},
	{"id": "repair_field", "name": "Repair Field", "source": "module", "tag": "repair",
		"desc": "Channel a repair field — mend hull and armor on yourself and nearby allies. Science-officer tech."},
	{"id": "tangle_shot", "name": "Tangle Shot", "source": "module", "tag": "tangle",
		"desc": "Fire a clinging charge at your target: drag and cut its thrust for a few seconds. Miner tech — a rock-cutter turned net."},
	{"id": "warp_jump", "name": "Micro-Warp", "source": "module", "tag": "warp",
		"desc": "A short controlled blink toward your selected target. Scout tech — repositioning in a flash."},
	{"id": "crystal", "name": "Crystalline Array", "source": "module", "tag": "crystal",
		"desc": "Place a point-defense screen at your cursor — it cuts every hostile warhead that enters, for a few seconds. Miner tech: stops ordnance, not gunfire."},
	{"id": "overload", "name": "Overload Pulse", "source": "module", "tag": "overload",
		"desc": "Instant EMP: collapse your target's shields for a few seconds, then they blink back exactly as strong as before. Science tech — an opening, not damage."},
	{"id": "killshot", "name": "Killshot", "source": "module", "tag": "killshot",
		"desc": "Line a distant mark up in your forward arc and it cannot miss. Scout tech — heavy, blunted by live shields, useless up close."},
	{"id": "blight", "name": "Withering Timbers", "source": "module", "tag": "blight",
		"desc": "Infect your target with a nanobot blight that eats the hull from the molecules up, biting every few seconds for half a minute. Privateer tech."},
	{"id": "lance", "name": "Hyper-Conductive Lance", "source": "module", "tag": "lance",
		"desc": "Throw a charged javelin of energy that bends slightly toward your mark. Guardian tech — heavy hit, brief recharge."},
	{"id": "repair_drone", "name": "Tender Drone", "source": "module", "tag": "repair_drone",
		"desc": "Launch a tender drone that circles your selected ally, mending them every few seconds for half a minute. Trader tech — fire and forget."},
	{"id": "blackout", "name": "Blackout", "source": "module", "tag": "blackout",
		"desc": "Kill your transponder — go briefly untargetable, long enough to break contact. Trader tech."},
]


static func def(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


static func display_name(id: String) -> String:
	var d := def(id)
	return str(d.get("name", id)) if not d.is_empty() else id


static func describe(id: String) -> String:
	return str(def(id).get("desc", ""))


## Ability art is DROP-IN at assets/icons/abilities/<id>.png — no code, no .tres.
## Callers must handle null (the gem bar and the book both fall back to text), so
## a new ability works the day it is written and gets its face whenever art lands.
static func icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex: Texture2D = null
	var p := "res://assets/icons/abilities/%s.png" % id
	if id != "" and ResourceLoader.exists(p):
		tex = load(p)
	_icon_cache[id] = tex
	return tex


## Which ability does this module/chip TAG grant? The inverse of the `tag` field,
## used to give a component the face of the ability it carries.
static func id_for_tag(tag: String) -> String:
	for a in LIST:
		if str(a.get("tag", "")) == tag:
			return str(a.id)
	return ""


## RICH TOOLTIP BODY (BBCode) for an ability — what it costs, what grants it,
## whether it can actually fire right now, and which key it sits on.
##
## Equipment got a proper hover panel long ago; abilities were still a bare
## description string, which stopped being acceptable the day energy shipped:
## nothing anywhere told the player what pressing a gem would COST them.
##
## Returns a STRING, not a Control, so this file stays UI-free and keeps parsing
## under `--script` (which has no autoloads) for tools/test_abilities.gd.
## `ship` is duck-typed: pass null from a screen with no boarded ship.
static func tooltip_body(aid: String, ship = null, known: Array = []) -> String:
	var out := ""
	var tag := str(def(aid).get("tag", ""))
	var st: Dictionary = {}
	if ship != null and ship.has_method("ability_stats"):
		st = ship.ability_stats(aid)

	# THE NUMBERS FIRST — cost, then how long it takes, then how often you get
	# it back. This is the block a pilot is actually reading when comparing two
	# abilities for one gem slot.
	if not st.is_empty():
		var cost := float(st.get("energy", 0.0))
		if cost <= 0.0:
			out += "[color=#8fe08f]No energy cost[/color]
"
		else:
			var afford: bool = not ("energy" in ship) or ship.energy >= cost
			out += "[color=%s]Energy       %.0f[/color]%s
" % [
				"#8fe08f" if afford else "#d4756b", cost,
				"" if afford else "  [color=#d4756b](not enough)[/color]"]
		if st.has("channel"):
			out += "[color=#a8b0c2]Channel      %.1fs[/color]
" % float(st.channel)
		if st.has("cd_max") and float(st.cd_max) > 0.0:
			var left := float(st.get("cd", 0.0))
			out += "[color=%s]Cooldown     %.0fs%s[/color]
" % [
				"#d4756b" if left > 0.0 else "#a8b0c2", float(st.cd_max),
				"   (%.0fs remaining)" % left if left > 0.0 else ""]
		if st.has("duration"):
			out += "[color=#a8b0c2]Duration     %.0fs[/color]
" % float(st.duration)
		if st.has("range"):
			var rmin := float(st.get("min_range", 0.0))
			out += "[color=#a8b0c2]Range        %s%.0f[/color]
" % [
				"%.0f–" % rmin if rmin > 0.0 else "", float(st.range)]
		if st.has("radius"):
			out += "[color=#a8b0c2]Radius       %.0f[/color]
" % float(st.radius)
		if st.has("cone"):
			out += "[color=#a8b0c2]Firing cone  %.0f°[/color]
" % float(st.cone)
		if st.has("effect"):
			out += "[color=#8fe08f]%s[/color]
" % str(st.effect)
		if st.has("note"):
			out += "[color=#8890a0]%s[/color]
" % str(st.note)
		out += "
"

	# WHERE IT COMES FROM. A gem fires only while its module is fitted, so the
	# tooltip has to say plainly whether it is aboard.
	if tag != "":
		out += "[color=#8890a0]Granted by a module tagged[/color] [b]%s[/b]
" % tag
	if not known.is_empty():
		out += ("[color=#8fe08f]Fitted — ready to fire.[/color]
" if known.has(aid)
			else "[color=#d4756b]Not fitted — this gem will not fire.[/color]
")

	for i in Pilot.GEM_SLOTS:
		if Pilot.gem_at(i) == aid:
			out += "[color=#f2b859]Wired to key [%d][/color]
" % (i + 1)
			break

	return out + "
[color=#a8b0c2]%s[/color]" % describe(aid)


static func ids() -> Array:
	var out := []
	for a in LIST:
		out.append(a.id)
	return out


## The ability a single component GRANTS (a fitted-in-a-slot activatable
## SystemDef), or {} — so the shop/detail UI can shout "GRANTS: Survey Scan".
static func granted_by(comp) -> Dictionary:
	# Chips grant abilities now; SystemDefs still answer so any legacy module
	# (and old saves that still carry one) keeps working.
	if comp is AbilityChipDef or comp is SystemDef:
		for a in LIST:
			if str(a.get("source", "")) == "module" and comp.has_tag(str(a.tag)):
				return a
	return {}


## The ability ids a build KNOWS right now: one per fitted activatable system
## whose tag matches a module ability. (Trained "skill"-source actives fold in
## here once professions grant them.) Duplicates collapse.
static func known_for_build(build: ShipBuild) -> Array:
	var out := []
	if build == null or build.hull == null:
		return out
	for a in LIST:
		if str(a.get("source", "")) != "module" or out.has(a.id):
			continue
		var tag := str(a.tag)
		# CHIPS IN THE COUPLING are the source now. Fitted modules still count so
		# pre-Coupling saves don't silently lose the abilities they had.
		if build.has_chip_tag(tag) or build.has_system_tag(tag):
			out.append(a.id)
	return out

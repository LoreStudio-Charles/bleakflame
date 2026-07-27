class_name GroundCombat
extends RefCounted
## THE COMBAT VERBS ON FOOT — target selection, the input scheme, and technique
## execution — with no planet in them.
##
## WHY (user, 2026-07-27): two more planets are coming, and none of this was ever about
## Epharon. Fighting works the same on every surface; only the scenery differs.
##
## THREE JOBS, SPLIT BY WHO ASKS (docs/engineering_principles.md, SRP):
##   · QUERIES — who is under the cursor, who is nearest. Static and PURE: call them twice,
##     in any order, from a test or a draw loop, and nothing moves.
##   · INPUT — edge-detected keys and mouse. Owns the "was down last frame" state, which is
##     the only reason this is an object rather than a pile of statics.
##   · TECHNIQUES — the refusal ladder, the cooldowns, and the dispatch.
##
## PRESENTATION IS NOT OURS (DIP). Every message goes out through the `notify` Callable the
## scene hands in, so this decides WHAT to say and the scene decides HOW to show it. A town
## with a caption label and a future scene with a comms overlay both work, and neither is
## named in here.

## How near the cursor must be to a body to mean it. Generous, because a 32px character on
## a wide field is a small thing to ask someone to hit.
const CLICK_REACH := 46.0
## Beyond this, [Q] and [TAB] will not reach out and pick a fight for you.
const CYCLE_RANGE := 900.0

var walker: GroundCharacter          # whose hands these verbs are
var world: Node2D                    # the y-sorted world, for the mouse position
var notify: Callable                 # (text: String, secs: float) -> void
## Technique id -> seconds remaining. HANDED OUT LIVE to the technique bar, which reads it
## and never writes — the bar shows what is true rather than keeping its own tally.
var cooldowns := {}
## The stance the player CHOSE, as opposed to the pose they are currently in: meditating
## borrows the kneel and must give it back on standing up.
var kneeling := false

var _lmb_was := false
var _rmb_was := false
var _q_was := false
var _tab_was := false
var _kneel_was := false
var _med_was := false
var _tech_was := {}                  # bus slot -> key held last frame


func _init(p_walker: GroundCharacter, p_world: Node2D, p_notify: Callable) -> void:
	walker = p_walker
	world = p_world
	notify = p_notify


# ---------------------------------------------------------------- queries (pure)

## The hostile under a world point, or null. Bodies are picked at CHEST height rather than
## at the feet-anchored origin, because that is where the eye says the creature is.
static func hostile_at(tree: SceneTree, point: Vector2,
		reach := CLICK_REACH) -> GroundCharacter:
	var best: GroundCharacter = null
	var best_d := reach
	for n in tree.get_nodes_in_group("ground_hostiles"):
		var g := n as GroundCharacter
		if g == null or g.dead:
			continue
		var d := point.distance_to(g.global_position - Vector2(0, 24))
		if d < best_d:
			best_d = d
			best = g
	return best


## Nearest live hostile to `from`, or the NEXT one after `after` — one function for both
## "pick me a fight" and "cycle", because they differ only in where the ring starts.
static func nearest_hostile(tree: SceneTree, from: Vector2,
		after: GroundCharacter = null, max_range := CYCLE_RANGE) -> GroundCharacter:
	var all: Array = []
	for n in tree.get_nodes_in_group("ground_hostiles"):
		var g := n as GroundCharacter
		if g != null and not g.dead and from.distance_to(g.global_position) < max_range:
			all.append(g)
	if all.is_empty():
		return null
	all.sort_custom(func(a, b) -> bool:
		return from.distance_to(a.global_position) < from.distance_to(b.global_position))
	if after != null and all.has(after):
		return all[(all.find(after) + 1) % all.size()]
	return all[0]


## Is anything hostile within reach — for a tutor or a UI that only needs the yes/no.
func hostile_near() -> bool:
	return nearest_hostile(walker.get_tree(), walker.global_position) != null


# ---------------------------------------------------------------- input

## LMB = SELECT (a click on a hostile targets it; holding still walks). RMB on a hostile =
## target AND engage — picking a fight and starting it are one gesture. [Q] weapons-free,
## [TAB] cycles, [SPACE] kneels, [K] meditates, [1]-[5] techniques.
func poll() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var tree := walker.get_tree()
	var mouse := world.get_global_mouse_position()

	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb and not _lmb_was:
		var hit := hostile_at(tree, mouse)
		if hit != null:
			walker.combat_target = hit
	_lmb_was = lmb

	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rmb and not _rmb_was:
		var hit := hostile_at(tree, mouse)
		if hit != null:
			walker.engage(hit)
			Tutor.did("ground_engaged")
	_rmb_was = rmb

	var q := Input.is_key_pressed(Keys.WEAPONS_FREE)
	if q and not _q_was:
		walker.auto_attack = not walker.auto_attack
		if walker.auto_attack and walker.combat_target == null:
			walker.combat_target = nearest_hostile(tree, walker.global_position)
		if not walker.auto_attack:
			walker.set_pose("kneeling" if kneeling else "")
		_say("WEAPONS FREE" if walker.auto_attack else "WEAPONS TIGHT", 1.0)
		Tutor.did("ground_weapons_toggled")
	_q_was = q

	var tabk := Input.is_key_pressed(Keys.CYCLE_FOE)
	if tabk and not _tab_was:
		walker.combat_target = nearest_hostile(tree, walker.global_position,
			walker.combat_target)
	_tab_was = tabk

	var kneel := Input.is_key_pressed(Keys.BRAKE)
	if kneel and not _kneel_was:
		kneeling = not kneeling
		walker.set_pose("kneeling" if kneeling else "")
		Tutor.did("ground_kneeled")
	_kneel_was = kneel

	# [K] MEDITATE — the Going-Dark mirror on foot: power down into the cell, refill fast,
	# defenceless while you are down. Kneeling is the pose either way, so leaving meditation
	# restores whatever stance you chose.
	var med := Input.is_key_pressed(Keys.DARK)
	if med and not _med_was:
		walker.set_meditating(not walker.meditating)
		if not walker.meditating and kneeling:
			walker.set_pose("kneeling")
		_say("MEDITATING — systems down, cell charging" if walker.meditating
			else "Up. Systems live.", 1.6)
		Tutor.did("meditated")
	_med_was = med

	# [1]-[5] TECHNIQUES — the character's own bus (Pilot.techniques), distinct from the
	# ship's gems by design: hardware vs training.
	for i in Techniques.BUS_SLOTS:
		var down := Input.is_key_pressed(Keys.ability_key(i))
		if down and not _tech_was.get(i, false):
			use(i)
		_tech_was[i] = down


# ---------------------------------------------------------------- techniques

func tick(delta: float) -> void:
	for tid in cooldowns.keys():
		var left: float = float(cooldowns[tid]) - delta
		if left <= 0.0:
			cooldowns.erase(tid)
		else:
			cooldowns[tid] = left


## Fire the technique prepared in bus slot `i`. Returns whether it actually went off.
##
## EVERY refusal is loud and specific (the ship's _ability_fail rule, mirrored) — and the
## invariant that matters: the cell and the cooldown are only ever charged AFTER the last
## refusal, so a refused technique costs nothing.
func use(i: int) -> bool:
	var tid := Pilot.technique_at(i)
	if tid == "":
		return _refuse("[%d] IS EMPTY — prepare a technique in your dossier [P]" % (i + 1))
	var d := Techniques.def(tid)
	if d.is_empty() or walker.dead:
		return false
	if walker.meditating:
		return _refuse("%s — YOU'RE MEDITATING" % str(d.name).to_upper())
	if walker.is_stunned():
		return _refuse("%s — YOU'RE REELING" % str(d.name).to_upper())
	if cooldowns.get(tid, 0.0) > 0.0:
		return _refuse("%s — %.0fs LEFT" % [str(d.name).to_upper(), float(cooldowns[tid])])
	# Target-needing techniques check the target BEFORE the cell is touched.
	var target := walker.combat_target
	if tid == "sand_kick":
		if target == null or not is_instance_valid(target) or target.dead:
			return _refuse("KICK SAND — NO TARGET")
		if walker.global_position.distance_to(target.global_position) > float(d.range):
			return _refuse("KICK SAND — OUT OF RANGE")
	if tid == "field_patch" and walker.health >= walker.max_health:
		return _refuse("FIELD PATCH — YOU'RE UNHURT")
	if not walker.spend_energy(float(d.get("energy", 0.0))):
		return _refuse("%s — NOT ENOUGH ENERGY" % str(d.name).to_upper())
	cooldowns[tid] = float(d.get("cooldown", 0.0))
	Tutor.did("used_technique")   # after every refusal, so only a real cast counts
	# ---- the dispatch (one arm per Techniques.LIST entry; effects live on the character) ----
	match tid:
		"field_patch":
			var healed := walker.mend(float(d.heal))
			_say("FIELD PATCH — mended %d" % int(healed), 1.6)
		"sand_kick":
			target.apply_stun(float(d.duration))
			_say("KICK SAND — it reels, clawing at its eyes", 1.8)
		"second_wind":
			walker.apply_haste(float(d.duration))
			_say("SECOND WIND", 1.4)
		"brace":
			walker.apply_brace(float(d.duration), float(d.mitigation))
			_say("BRACED — set your feet", 1.6)
	Sfx.play("pickup", -10.0)
	return true


## The unmistakable refusal (ship rule: loud, distinct from the soft nav click). Returns
## false so every guard above can `return _refuse(...)` and read as one ladder.
func _refuse(reason: String) -> bool:
	_say("✕ " + reason, 2.2)
	Sfx.play("click", -6.0, 0.32)
	return false


func _say(text: String, secs: float) -> void:
	if notify.is_valid():
		notify.call(text, secs)

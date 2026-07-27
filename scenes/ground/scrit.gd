class_name Scrit
extends GroundCharacter
## The SCRIT (docs/ground_combat.md; user: "akin to jawa", renamed from "dust goblin"
## 2026-07-25 — one syllable, and it sounds like the noise they make) — a small hooded
## scavenger of the open roam. Pack-brave, alone-cowardly, and a scavenger to the bone:
## it BREAKS AND RUNS at low health rather than dying proudly. The first ground enemy.
##
## Lives in AUTHORED PLACES (the warren the town spawns), never on-player spawns —
## the living-world rule, same as pirates. THE TOWN IS SANCTUARY (the station-sanctuary
## mirror): a scrit never crosses the colony's light, however hungry.

const NOTICE_RANGE := 420.0
const LEASH_RANGE := 950.0        # gives up beyond this from home and skulks back
const FLEE_HEALTH := 0.3          # break-and-run below 30% — scavengers, not soldiers
const PACK_RANGE := 260.0         # a scrit with a friend this close is BRAVE
## The colony's light. Scrit stop dead at this radius from town center — the ground
## mirror of AIShip.SANCTUARY_R. Buildings sit within ~1000u of Vector2.ZERO.
const TOWN_SANCTUARY_R := 1150.0

var home := Vector2.ZERO
var looted := false
## CORNERED: no line of retreat, so the break-and-run never triggers. Set on packs in
## ENCLOSED places (the wrecked cave) for two reasons — one fictional, one practical.
## A scavenger runs because running works; in a room with one mouth it doesn't, and a
## cornered animal is the more dangerous one. Practically, FLEE_HEALTH would send it
## sprinting for a `home` that is inside the room with you, so it would jitter against
## the walls in front of the player instead of escaping. Trapped means trapped.
var cornered := false
## LYING IN WAIT. A dormant scrit is invisible, inert and unfindable — it does not think,
## move, or answer a scan. The AMBUSH is the one authored exception to "enemies live in
## places you can see": these are hidden behind a dune on the road to the hermit, and the
## whole point is that the first you know of them is the moment they break cover.
var dormant := false
var _wander_t := 0.0
var _flee_t := 0.0


func setup_scrit(spawn: Vector2) -> void:
	setup("res://assets/characters/Scrit")
	home = spawn
	global_position = spawn
	display_name = "Scrit"
	team = "hostile"
	max_health = 34.0
	health = max_health
	mitigation = 0.05              # rags, not plating
	speed = 150.0
	set_melee(7.0, 40.0, 1.1)      # claw swipe
	add_to_group("ground_hostiles")
	died.connect(_become_corpse)


## Death -> the fall plays -> the body SETTLES into the user's dead state and becomes a
## LOOT CONTAINER (group ground_loot; the town offers [E]/RMB Scavenge). Scavengers get
## scavenged — that's the desert.
func _become_corpse() -> void:
	remove_from_group("ground_hostiles")
	_roll_haul()                    # decided when it falls, not when it is searched
	var tw := create_tween()
	tw.tween_interval(1.1)          # let the falling-back-death play out
	tw.tween_callback(func() -> void:
		play_action("dead", 1.0, true)   # the corpse sprite, held
		add_to_group("ground_loot"))


## What a scrit might be clutching — the ground drop pool. Rolled through the same
## Affixes.roll_for_drop as ship salvage, so a "Hardened Rag Hood" is a real find.
const DROP_POOL := ["res://data/ground/scrap_shiv.tres", "res://data/ground/rag_hood.tres",
	"res://data/ground/work_gloves.tres"]
const GEAR_DROP_CHANCE := 0.22


## WHAT THIS BODY IS HOLDING, rolled when it falls rather than when it is searched.
## Two reasons: a search that can't take everything must not re-roll a DIFFERENT
## prize on the next try, and the corpse can only go on holding something it
## already decided it had.
var held_credits := 0
var held_gear: GroundGearDef = null


func _roll_haul() -> void:
	held_credits = 3 + randi() % 7
	if randf() < GEAR_DROP_CHANCE:
		var path: String = DROP_POOL[randi() % DROP_POOL.size()]
		if ResourceLoader.exists(path):
			held_gear = Affixes.roll_for_drop(load(path))


## Scavenge: a fistful of trinkets, and the thing it was clutching if you have room
## for it. The body only fades once it is EMPTY.
##
## `take_gear` false leaves the gear ON THE BODY and the corpse searchable. It used
## to hand the item over unconditionally and fade regardless, so a full hold
## DESTROYED the drop — the caller printed "but your hold is full" and the affixed
## find, which the same roll_for_drop that makes ship salvage worth flying for had
## just generated, ceased to exist. Of the seven "give the player this item" paths
## in the codebase this was the only one that silently destroyed anything.
func loot(take_gear := true) -> Dictionary:
	if looted:
		return {}
	var haul := {}
	if held_credits > 0:
		haul["credits"] = held_credits
		held_credits = 0
	if held_gear != null and take_gear:
		haul["gear"] = held_gear
		held_gear = null
	if held_gear != null:
		return haul                      # still clutching it — stay searchable
	looted = true
	remove_from_group("ground_loot")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
	return haul


## Go to ground behind cover: hidden and inert until sprung. Called at spawn.
func lie_in_wait() -> void:
	dormant = true
	visible = false
	auto_attack = false
	combat_target = null
	remove_from_group("ground_hostiles")   # nothing can target or count it while it hides


## BREAK COVER. Reveals, rejoins the hostiles, and comes straight at `prey`.
func spring(prey: GroundCharacter) -> void:
	if not dormant:
		return
	dormant = false
	visible = true
	add_to_group("ground_hostiles")
	home = global_position   # it leashes to where it was hiding, not to a distant warren
	engage(prey)


func _physics_process(delta: float) -> void:
	if dormant:
		return   # lying in wait: no thinking, no drifting, no shadow of a tell
	if dead:
		super._physics_process(delta)
		return
	_think(delta)
	super._physics_process(delta)


func _think(delta: float) -> void:
	_wander_t -= delta
	if _flee_t > 0.0:
		_flee_t -= delta
	var prey := _find_prey()

	# BREAK AND RUN: a wounded scavenger stops fighting and bolts home — unless it has
	# nowhere to bolt TO (see `cornered`), in which case it fights to the end.
	if not cornered and health < max_health * FLEE_HEALTH:
		auto_attack = false
		combat_target = null
		_flee_t = 2.0
		move_to(home)
		return
	if _flee_t > 0.0:
		return

	if prey == null:
		# Skulk: drift around the warren.
		auto_attack = false
		combat_target = null
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.8, 4.0)
			var a := randf() * TAU
			move_to(home + Vector2(cos(a), sin(a)) * randf_range(40.0, 220.0))
		return

	# PACK COURAGE: alone it hangs back at the edge of its notice range and chitters;
	# with a packmate nearby it commits.
	# PACK COURAGE — but a CORNERED scrit has no hesitation to spend. This is the ground
	# echo of a SPACE rule (a lone hunter hangs back until the odds improve), and it does
	# not belong in a sealed room: the last survivor of the cave pack simply refused to
	# close (playtest: "one of the Scrit didn't attack"). Trapped means committed — the
	# same flag that stops it fleeing stops it dithering.
	if not cornered and not _pack_near() 			and global_position.distance_to(prey.global_position) > 150.0:
		auto_attack = false
		move_to(home.lerp(prey.global_position, 0.35))
		return

	# THE RUSH — but never into the colony's light, and never past the leash.
	engage(prey)
	var dest := prey.global_position
	if dest.length() < TOWN_SANCTUARY_R:
		# Prey stands in sanctuary: stop AT the light's edge and pace, robbed.
		auto_attack = false
		dest = dest.normalized() * (TOWN_SANCTUARY_R + 40.0)
	if home.distance_to(dest) > LEASH_RANGE:
		auto_attack = false
		move_to(home)
		return
	if global_position.distance_to(prey.global_position) > float(attack_spec.range) * 0.9:
		move_to(dest)
	else:
		stop()


func _find_prey() -> GroundCharacter:
	var best: GroundCharacter = null
	var best_d := NOTICE_RANGE
	for n in get_tree().get_nodes_in_group("player_walker"):
		var w := n as GroundCharacter
		if w == null or w.dead:
			continue
		var d := global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best


func _pack_near() -> bool:
	for n in get_tree().get_nodes_in_group("ground_hostiles"):
		if n != self and is_instance_valid(n) and not n.dead \
				and global_position.distance_to(n.global_position) < PACK_RANGE:
			return true
	return false

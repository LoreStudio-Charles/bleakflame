class_name DustGoblin
extends GroundCharacter
## The DUST GOBLIN (docs/ground_combat.md; user: "akin to jawa") — a small hooded
## scavenger of the open roam. Pack-brave, alone-cowardly, and a scavenger to the bone:
## it BREAKS AND RUNS at low health rather than dying proudly. The first ground enemy.
##
## Lives in AUTHORED PLACES (the warren the town spawns), never on-player spawns —
## the living-world rule, same as pirates. THE TOWN IS SANCTUARY (the station-sanctuary
## mirror): a goblin never crosses the colony's light, however hungry.

const NOTICE_RANGE := 420.0
const LEASH_RANGE := 950.0        # gives up beyond this from home and skulks back
const FLEE_HEALTH := 0.3          # break-and-run below 30% — scavengers, not soldiers
const PACK_RANGE := 260.0         # a goblin with a friend this close is BRAVE
## The colony's light. Goblins stop dead at this radius from town center — the ground
## mirror of AIShip.SANCTUARY_R. Buildings sit within ~1000u of Vector2.ZERO.
const TOWN_SANCTUARY_R := 1150.0

var home := Vector2.ZERO
var looted := false
var _wander_t := 0.0
var _flee_t := 0.0


func setup_goblin(spawn: Vector2) -> void:
	setup("res://assets/characters/DustGoblin")
	home = spawn
	global_position = spawn
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
	var tw := create_tween()
	tw.tween_interval(1.1)          # let the falling-back-death play out
	tw.tween_callback(func() -> void:
		play_action("dead", 1.0, true)   # the corpse sprite, held
		add_to_group("ground_loot"))


## What a goblin might be clutching — the ground drop pool. Rolled through the same
## Affixes.roll_for_drop as ship salvage, so a "Hardened Rag Hood" is a real find.
const DROP_POOL := ["res://data/ground/scrap_shiv.tres", "res://data/ground/rag_hood.tres",
	"res://data/ground/work_gloves.tres"]
const GEAR_DROP_CHANCE := 0.22


## One scavenge per corpse: a fistful of trinkets — and sometimes the thing it was
## clutching ("gear": GroundGearDef, affix-rolled) — then the body fades.
func loot() -> Dictionary:
	if looted:
		return {}
	looted = true
	remove_from_group("ground_loot")
	var credits := 3 + randi() % 7
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
	var haul := {"credits": credits}
	if randf() < GEAR_DROP_CHANCE:
		var path: String = DROP_POOL[randi() % DROP_POOL.size()]
		if ResourceLoader.exists(path):
			haul["gear"] = Affixes.roll_for_drop(load(path))
	return haul


func _physics_process(delta: float) -> void:
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

	# BREAK AND RUN: a wounded scavenger stops fighting and bolts home.
	if health < max_health * FLEE_HEALTH:
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
	if not _pack_near() and global_position.distance_to(prey.global_position) > 150.0:
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

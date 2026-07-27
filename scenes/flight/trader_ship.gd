class_name TraderShip
extends AIShip
## A NEUTRAL Trader-guild hauler — civilian traffic, NOT a combatant. It runs its
## patrol route (station <-> planet, station <-> gate), turns up in the friendlies
## roster (click a row to target), and can be hailed.
##
## It rides "player_team" so PIRATES prey on it (the living-world raids), but it
## is only in "hostile_team" — the player's targetable set — once you DECLARE WAR
## on the Trader guild (the peace toggle), so you can never fat-finger your way to
## outlaw. Damage is attributed by SOURCE:
##  • The PLAYER shooting it = a CRIME — it flees, you go WANTED, and killing it
##    spills plunder while Trader/Guardian standing crater and Privateer climbs.
##  • A PIRATE shooting it = a DEFEND opportunity — no crime on you; save it (kill
##    its attacker before it dies) and Guardian + Trader standing thank you.
## The guardian/turret civilian filter keeps the LAW from ever firing on a hauler.

# Crime weights on the signed [-1000,1000] standing scale. Losses are BIG (fast
# to burn), so redemption (slow, via the hermit) can never let you ally both.
const CRIME_ATTACK_GUARDIAN := -3     # winging a civilian, witnessed
const CRIME_KILL_GUARDIAN := -50      # a killed civilian — a serious lawful crime
const CRIME_KILL_TRADER := -40        # you robbed Imari's people
const CRIME_KILL_PRIVATEER := 8       # the Shoal respects a good score
const DEFEND_GUARDIAN := 8            # you protected the lane
const DEFEND_TRADER := 6              # Imari's grateful
const WANTED_SECONDS := 40.0
const SQUAWK_RANGE := 2200.0          # only trouble the player's HUD if they're near

var cargo_manifest := {}      # commodity key -> units the hauler is carrying
var _fleeing := false
var _flee_from: Node = null   # whoever last shot us — we run from THEM
var _player_attacked := false
var _saved := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	ally_groups = ["player_team", "friendly_targets"]
	add_to_group("friendly_targets")   # friendlies roster + hailable
	add_to_group("traders")
	add_to_group("player_team")         # so PIRATES hunt it (guns target player_team)
	refresh_hostility()


func setup_trader(new_build: ShipBuild, tint: Color = Color(0.72, 0.68, 0.56)) -> void:
	use_variant_skin = true
	apply_build(new_build)
	set_hull_tint(tint)
	# LICENSED FREIGHT. The registry is what makes the lane read as a governed road
	# rather than a spawn field — and it is what a hail has to say back.
	faction = "civilian"
	ship_name = ShipNames.registry("hauler")
	_seed_cargo()


## A small, varied manifest — the plunder you steal (and the traders' economic
## reason to exist). Modest so piracy pays but never trivialises loot.
func _seed_cargo() -> void:
	var pool := ["food", "water", "circuits", "ferrite_ore", "cobalt_ore"]
	cargo_manifest = {}
	for i in 2 + randi() % 2:
		var key: String = pool[randi() % pool.size()]
		cargo_manifest[key] = int(cargo_manifest.get(key, 0)) + 1 + randi() % 2


## Peace with the Trader guild = untargetable friendly (to the PLAYER). Declare
## war (peace off) and the hauler joins "hostile_team" so the player's guns reach
## it. (Pirates hunt it regardless — that's the player_team membership.)
func refresh_hostility() -> void:
	var war := Standing.at_war("trader")
	if war and not is_in_group("hostile_team"):
		add_to_group("hostile_team")
	elif not war and is_in_group("hostile_team"):
		remove_from_group("hostile_team")


func take_damage(amount: float, source: Node = null) -> void:
	super(amount, source)   # base damage (AIShip's pirate-flee state is inert for us)
	if dead:
		return
	_last_attacker = source
	_flee_from = source
	if not _fleeing:
		_fleeing = true
		_squawk(source)
	if _is_player(source):
		if not _player_attacked:
			_player_attacked = true
			Standing.add("guardian", CRIME_ATTACK_GUARDIAN)   # the law notes an assault
		if source.has_method("mark_wanted"):
			source.mark_wanted(WANTED_SECONDS)   # each hit keeps the heat on
	elif source is AIShip and not source.is_in_group("traders"):
		_watch_savior(source)   # a pirate raid — reward whoever downs the pirate


## Distress broadcast — only troubles the player's HUD if they're close enough to
## actually respond (else the hauler dies off-screen, part of the living world).
func _squawk(source: Node) -> void:
	Sfx.play_at("shield_hit", global_position, -4.0, 0.7)
	var p := _player()
	if p == null or not p.has_method("_flash_note"):
		return
	if global_position.distance_to((p as Node2D).global_position) > SQUAWK_RANGE:
		return
	if _is_player(source):
		p._flash_note("DISTRESS — %s: \"Mayday! We're being ROBBED!\"  (you are now WANTED)"
			% build.hull.display_name)
	else:
		p._flash_note("DISTRESS — %s: \"Pirate on us — anyone!\"  (defend for standing)"
			% build.hull.display_name)


func _watch_savior(pirate: Node) -> void:
	var ai := pirate as AIShip
	if ai != null and not ai.died.is_connected(_on_savior):
		# Bind the pirate so the handler can ask WHO killed it. `died` carries no
		# source of its own.
		ai.died.connect(_on_savior.bind(ai), CONNECT_ONE_SHOT)


## The pirate that was hunting us died and we're still flying — IF THE PLAYER
## KILLED IT. The guild and the law remember it (the DEFEND side of the fork).
##
## This used to fire on the pirate's death no matter whose guns did it. The lane
## is a living world running from t=0: Guardian lane patrols shoot pirates and
## Cinderweb eats them, so a pilot collected +8 Guardian / +6 Trader for rescues
## they were not present for and docked into a fresh game already at INVITE_AT,
## with two commission doors standing open. Standing must be EARNED.
func _on_savior(pirate: Node) -> void:
	if dead or _saved:
		return
	# Not your kill — a patrol, the beast, or another pirate got it. Leave
	# `_saved` alone so a real rescue from the NEXT hunter still counts.
	if not is_instance_valid(pirate) or not pirate.killed_by_player():
		return
	_saved = true
	Standing.add("guardian", DEFEND_GUARDIAN)
	Standing.add("trader", DEFEND_TRADER)
	var p := _player()
	if p != null and p.has_method("_flash_note") \
			and global_position.distance_to((p as Node2D).global_position) <= SQUAWK_RANGE:
		p._flash_note("%s: \"You saved us! The guild won't forget.\"  (+standing)"
			% build.hull.display_name)


func _physics_process(delta: float) -> void:
	if build == null or dead:
		return
	tick_common(delta)
	refresh_hostility()   # self-heal to any war/peace change (toggle, event, mend)
	var thrust := Vector2.ZERO
	if _fleeing and _flee_from != null and is_instance_valid(_flee_from):
		# Run — full burn directly away from whoever's shooting us.
		var away := (global_position - (_flee_from as Node2D).global_position).normalized()
		rotation = rotate_toward(rotation, away.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	elif not patrol_points.is_empty():
		var goal := patrol_points[_patrol_index]
		if global_position.distance_to(goal) < PATROL_ARRIVE:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			goal = patrol_points[_patrol_index]
		rotation = rotate_toward(rotation, (goal - global_position).angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel * PATROL_CRUISE
	var dodge := avoid_obstacles_dir(thrust)
	if dodge != Vector2.ZERO:
		rotation = rotate_toward(rotation, dodge.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	apply_movement(thrust, delta)


## Destroyed. If the PLAYER dealt the killing blow it's a robbery — spill the
## manifest + a fence-able token and settle the account. If a PIRATE killed it,
## the hauler is simply lost (they took the cargo); no plunder, no rap sheet.
func _on_death() -> void:
	if _is_player(_last_attacker):
		var here := get_parent()
		for key in cargo_manifest:
			for i in int(cargo_manifest[key]):
				LootPickup.spawn_commodity(here, global_position + _drop_jitter(), key)
		LootPickup.spawn_commodity(here, global_position, "stolen_goods")
		Standing.add("trader", CRIME_KILL_TRADER)
		Standing.add("guardian", CRIME_KILL_GUARDIAN)
		Standing.add("privateer", CRIME_KILL_PRIVATEER)
		if _last_attacker.has_method("mark_wanted"):
			_last_attacker.mark_wanted(WANTED_SECONDS)
	queue_free()


## Parameter is DELIBERATELY untyped: the attacker we stored may have been freed
## since (a pirate that shot us, then died before we did). A typed `node: Node`
## param would make GDScript reject a freed argument at the CALL — before the
## body runs — so is_instance_valid inside would never get the chance. Untyped,
## the freed reference reaches the guard, which correctly returns false.
func _is_player(node) -> bool:
	return is_instance_valid(node) and node.is_in_group("player_ship")


func _player() -> Node:
	return get_tree().get_first_node_in_group("player_ship")


func _drop_jitter() -> Vector2:
	return Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))

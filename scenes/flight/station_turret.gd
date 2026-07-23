class_name StationTurret
extends Node2D
## Station defense emplacement: a WeaponMount bolted to architecture. Two
## tiers, differentiated purely by weapon data + the traverse rule:
##   Heavy battery (Mk IV) — prefers the HEAVIEST target in reach; mauls
##     brawlers and future capital raiders, too slow to track a darting raider.
##   PD array (Mk I) — tracks anything, chips fast; prefers the NEAREST.
## Targets pirate ships only (practice drones get a pass).

enum TargetMode { NEAREST, HEAVIEST }

var mount: WeaponMount
var target_mode := TargetMode.NEAREST
## Whose ships this emplacement shoots at. The station guards against
## "hostile_team"; the Rust Shoal's guns guard against "player_team".
var faction_group := "hostile_team"

var _weapon_path := "res://data/components/weapons/skeet_pd_array.tres"


static func create(weapon_path: String, mode: TargetMode,
		faction := "hostile_team") -> StationTurret:
	var t := StationTurret.new()
	t._weapon_path = weapon_path
	t.target_mode = mode
	t.faction_group = faction
	return t


func _ready() -> void:
	var hp := HardpointDef.new()
	hp.display_name = "Defense Turret"
	hp.slot_type = HardpointDef.SlotType.WEAPON
	hp.arc_deg = 360.0
	var weapon: WeaponDef = load(_weapon_path)
	hp.mark = weapon.mark
	mount = WeaponMount.new()
	add_child(mount)
	mount.setup(hp, weapon, faction_group, "res://assets/mounts/turret_station.png")


func _physics_process(delta: float) -> void:
	var target := _pick_target()
	if target == null:
		return
	mount.aim_at(target.global_position, delta, target.velocity)
	if global_position.distance_to(target.global_position) <= mount.def.weapon_range:
		mount.fire()


func _pick_target() -> BuildShip:
	var best: BuildShip = null
	var best_score := -INF
	var track_range: float = mount.def.weapon_range * 1.35
	for node in get_tree().get_nodes_in_group(faction_group):
		var pirate := node as BuildShip
		if pirate == null or pirate.dead or pirate.is_in_group("traders"):
			continue   # station guns protect civilian traders, never fire on them
		# The Shoal's OWN guns (player_team faction) hold fire on a pilot it
		# welcomes — a parley, or one it's opened to. Station guns (hostile_team)
		# still gun down a wanted outlaw; the law doesn't forgive.
		if pirate.is_in_group("player_ship") and faction_group == "player_team" \
				and (AIShip.parley or Standing.shoal_open()):
			continue
		var d := global_position.distance_to(pirate.global_position)
		if d > track_range:
			continue
		var score: float = -d if target_mode == TargetMode.NEAREST \
			else pirate.stats.mass * 1000.0 - d
		if score > best_score:
			best_score = score
			best = pirate
	return best


func _draw() -> void:
	var r := 5.0 + 1.6 * mount.def.mark if mount != null else 8.0
	draw_circle(Vector2.ZERO, r, Color(0.24, 0.26, 0.32))
	draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(0.52, 0.56, 0.66), 1.5)

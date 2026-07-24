class_name Tutorial
extends Node
## Flight-control training CONTROLLER. The old gold top-bar is gone — the TEXT now
## lives in the Tutor as the "flight_training" lesson (centred captions, one system),
## and this node just drives the MECHANICS: input tracking, the 3 practice drones,
## and the 150c/50xp payout that kicks off the campaign. It reads the active Tutor
## step's `id` and calls Tutor.did() to complete each one. Runs once on a fresh save.

const REWARD_CREDITS := 150
const REWARD_XP := 50
const DRONE_COUNT := 3

## Step id -> VO clip. The controller plays it when a step first becomes active
## (the Tutor owns the caption; VO stays here since it's step-timed).
const VO_LINES := {
	"tut_launch": "tut_welcome", "tut_thrust": "tut_thrust", "tut_rotate": "tut_rotate",
	"tut_boostbrake": "tut_boost", "tut_drones": "tut_drones", "tut_dock": "tut_return",
}

var ship: TestShip
var _seen := {}
var _kills := 0
var _drones_spawned := false
var _paid := false
var _last_id := ""


func _init(p_ship: TestShip) -> void:
	ship = p_ship


func _ready() -> void:
	add_to_group("tutorial")   # ambient drone kills report here too
	Tutor.arm("flight_training")


func _process(_delta: float) -> void:
	if ship == null or ship.dead or _paid:
		return
	# The whole lesson finished (last step done) → pay out + kick the campaign.
	if Tutor.seen.has("flight_training"):
		_finish()
		return
	if Tutor.active != "flight_training":
		return
	var id := str(Tutor.current().get("id", ""))
	if id != _last_id and id != "":
		_last_id = id
		Sfx.play_voice(VO_LINES.get(id, ""))
	match id:
		"tut_launch":
			if ship.docked_at == null:
				Tutor.did("tut_launched")
		"tut_thrust":
			_mark("fore", "thrust_forward")
			_mark("aft", "thrust_back")
			if _seen.has("fore") and _seen.has("aft"):
				Tutor.did("tut_thrust")
		"tut_rotate":
			_mark("left", "thrust_left")
			_mark("right", "thrust_right")
			if _seen.has("left") and _seen.has("right"):
				Tutor.did("tut_rotate")
		"tut_boostbrake":
			_mark("boost", "boost")
			_mark("brake", "brake")
			if _seen.has("boost") and _seen.has("brake"):
				Tutor.did("tut_boostbrake")
		"tut_drones":
			if not _drones_spawned:
				_drones_spawned = true
				_spawn_drones()
			if _kills >= DRONE_COUNT:
				Tutor.did("tut_drones")
		"tut_dock":
			if ship.docked_at is DockingPad:
				Tutor.did("tut_docked")


func _mark(key: String, action: String) -> void:
	if Input.is_action_pressed(action):
		_seen[key] = true


func _spawn_drones() -> void:
	for i in DRONE_COUNT:
		var drone := TargetDrone.new()
		drone.position = ship.global_position \
			+ Vector2.RIGHT.rotated(TAU * i / DRONE_COUNT) * randf_range(380.0, 520.0)
		drone.destroyed.connect(_on_drone_killed)
		ship.get_parent().add_child(drone)


func _on_drone_killed() -> void:
	_kills += 1


## License earned: pay out, flag the save, and re-run the dock hook so the first
## campaign quest fires on THIS landing (the docking's inline on_dock ran a beat ago
## with tutorial_done still false, so Ruel never spoke — this un-sticks it).
func _finish() -> void:
	_paid = true
	Wallet.credits += REWARD_CREDITS
	Wallet.xp += REWARD_XP
	SaveGame.tutorial_done = true
	SaveGame.save_game(ship)
	if ship.docked_at is DockingPad:
		Quests.on_dock(true, ship, true)
	for screen in get_tree().get_nodes_in_group("dock_screens"):
		if screen.visible:
			screen.refresh()
	Sfx.play("jingle", -5.0)
	ship._flash_note("License earned. +%d credits, +%d XP." % [REWARD_CREDITS, REWARD_XP])
	queue_free()

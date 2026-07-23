class_name Tutorial
extends CanvasLayer
## Pilot license tutorial — runs once on a fresh save. A gold instruction bar
## walks launching, thrust, vectoring, boost/brake, then activates practice
## drones and pays out on returning to dock.
## Future variant (noted, not built): an ambush on the return leg when the
## player picked the fighter.

const SYSTEM_NAME := "Cinder Reach"

enum Step { WELCOME, THRUST, ROTATE, BOOST_BRAKE, DRONES, RETURN, DONE }

const REWARD_CREDITS := 150
const REWARD_XP := 50
const DRONE_COUNT := 3

var ship: TestShip
var step := Step.WELCOME
var _seen := {}
var _kills := 0
var _label: Label


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 6


func _ready() -> void:
	add_to_group("tutorial")   # ambient drone kills report here too
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 6
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.04, 0.92)
	style.border_color = Color(0.85, 0.72, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_label)
	_enter(Step.WELCOME)


func _process(_delta: float) -> void:
	if ship == null or ship.dead:
		return
	match step:
		Step.WELCOME:
			if ship.docked_at == null:
				_enter(Step.THRUST)
		Step.THRUST:
			_mark("fore", "thrust_forward")
			_mark("aft", "thrust_back")
			if _seen.has("fore") and _seen.has("aft"):
				_enter(Step.ROTATE)
		Step.ROTATE:
			_mark("left", "thrust_left")
			_mark("right", "thrust_right")
			if _seen.has("left") and _seen.has("right"):
				_enter(Step.BOOST_BRAKE)
		Step.BOOST_BRAKE:
			_mark("boost", "boost")
			_mark("brake", "brake")
			if _seen.has("boost") and _seen.has("brake"):
				_enter(Step.DRONES)
		Step.RETURN:
			if ship.docked_at is DockingPad:
				_finish()


func _mark(key: String, action: String) -> void:
	if Input.is_action_pressed(action):
		_seen[key] = true


const VO_LINES := {
	Step.WELCOME: "tut_welcome", Step.THRUST: "tut_thrust", Step.ROTATE: "tut_rotate",
	Step.BOOST_BRAKE: "tut_boost", Step.DRONES: "tut_drones", Step.RETURN: "tut_return",
}


func _enter(new_step: Step) -> void:
	step = new_step
	# Interruptible: finishing a step fast cuts its narration before the next
	# line starts, so tutorial VO never stacks on itself.
	Sfx.play_voice(VO_LINES[step] if VO_LINES.has(step) else "")
	match step:
		Step.WELCOME:
			_label.text = "Hello, Pilot. Welcome to %s. Let's make sure you've earned that pilot license.\nPress E to launch." % SYSTEM_NAME
		Step.THRUST:
			_label.text = "Fore and aft thrust — burn forward with W, then check your aft thrust with S.\n(Reverse burn is weak on every hull. Engines point backward.)"
		Step.ROTATE:
			_label.text = "Rotational vectoring — swing the nose with A and D.\nYour velocity keeps its heading until you burn against it."
		Step.BOOST_BRAKE:
			_label.text = "Hold SHIFT to boost. Hold SPACE to brake to a stop."
		Step.DRONES:
			_label.text = "Weapons online. Practice drones inbound — destroy %d of them. (0/%d)" % [DRONE_COUNT, DRONE_COUNT]
			_spawn_drones()
		Step.RETURN:
			# DOCKING LESSON. The old one-line hint ("green means clean") never
			# said there were TWO variables, nor that creeping is always safe —
			# which is exactly what made berthing read as confusing, not hard.
			_label.text = "Well flown, Pilot. Now bring her home and dock.\n" \
				+ "Two things matter: line up ALONG the approach lane, and ease off the throttle. " \
				+ "The chevrons grade you live — green is clean, amber scrapes the paint, red wrecks her.\n" \
				+ "When in doubt, CRAWL her in. A slow approach is always safe. Press E in range."


func _spawn_drones() -> void:
	for i in DRONE_COUNT:
		var drone := TargetDrone.new()
		drone.position = ship.global_position \
			+ Vector2.RIGHT.rotated(TAU * i / DRONE_COUNT) * randf_range(380.0, 520.0)
		drone.destroyed.connect(_on_drone_killed)
		ship.get_parent().add_child(drone)


func _on_drone_killed() -> void:
	if step != Step.DRONES:
		return
	_kills += 1
	if _kills >= DRONE_COUNT:
		_enter(Step.RETURN)
	else:
		_label.text = "Weapons online. Practice drones inbound — destroy %d of them. (%d/%d)" % [
			DRONE_COUNT, _kills, DRONE_COUNT]


func _finish() -> void:
	Wallet.credits += REWARD_CREDITS
	Wallet.xp += REWARD_XP
	SaveGame.tutorial_done = true
	SaveGame.save_game(ship)
	# This tutorial-completing dock ALREADY ran Quests.on_dock() a beat ago with
	# tutorial_done still false (ship.dock() fires it inline; _finish sets the
	# flag afterward). So the first campaign quest ("Standing With the Board")
	# never started and Ruel never spoke — you'd have had to undock and redock.
	# Now the licence is earned, re-run the dock hook so his briefing fires on
	# THIS landing; the refresh below presents the freshly-queued talk.
	if ship.docked_at is DockingPad:
		Quests.on_dock(true, ship, true)
	# The dock screen refreshed before the payout landed — update it so the
	# credits the bar promises are the credits the header shows (and so the
	# briefing just queued above is presented).
	for screen in get_tree().get_nodes_in_group("dock_screens"):
		if screen.visible:
			screen.refresh()
	Sfx.play("jingle", -5.0)
	_label.text = "License earned. +%d credits, +%d XP. %s is yours, Pilot." % [
		REWARD_CREDITS, REWARD_XP, SYSTEM_NAME]
	step = Step.DONE
	await get_tree().create_timer(7.0).timeout
	queue_free()

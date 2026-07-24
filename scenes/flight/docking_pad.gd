class_name DockingPad
extends Node2D
## The docking skill check. Pressing E in range evaluates the ship's velocity
## against the pad's approach lane (local +X points OUT of the slot; correct
## approach flies along -X). Clean = dock. Sloppy = dock with scrape damage
## through the normal shield->armor->hull flow. Terrible = crash: heavy
## damage, bounced out, no dock. Creeping in slowly is always safe.

const DOCK_RANGE := 58.0   # local units — scales with the station transform
const SPEED_LIMIT := 120.0
const CREEP_SPEED := 25.0
const CRASH_ERROR := 0.72
const SCRAPE_FREE_ERROR := 0.15
const CRASH_DAMAGE_SCALE := 190.0
const UI_RANGE := 640.0

## Largest hull this berth can physically take. A station is only as big as it
## is: the little Cinder Reach station tops out at MEDIUM, which is WHY the
## Reach only ever sees light + medium ships — heavies need a real port (a
## later system). Default accepts anything; the station sets its own cap.
var max_size_band: int = HullDef.SizeBand.SUPER_HEAVY_PLUS
## SMALLEST hull this berth will take. Default 0 (LIGHT) = no floor. A DRYDOCK
## sets this to SUPER_HEAVY so it REFUSES anything that could fit a landing bay —
## the capital's drydocks are for the big hulls a bay can't hold (>64px), and a
## fighter is waved off to a bay. The band boundary IS the 64px split (HullDef
## BAND_PX: HEAVY 64, SUPER_HEAVY 128).
var min_size_band: int = HullDef.SizeBand.LIGHT


## True if a hull of this size band may berth here (within [min, max]). Pure and
## save-free, so the whole size gate is testable without a real docking attempt
## (try_dock() routes its cap/floor refusals through this).
func size_permitted(size_band: int) -> bool:
	return size_band >= min_size_band and size_band <= max_size_band
## False for a bare berth (Orivel's capital pads for now): still repairs + saves +
## checkpoints like any dock, but runs NO station economy (no research calendar,
## no contract board, no auto-started quests) — the "no services yet" fiction.
var runs_dock_services := true
## Shown by a bespoke dock screen so the pilot knows which berth they took
## ("Landing Bay · East", "Drydock · NE"). Empty for the plain station pad.
var berth_label := ""
## True while a berthing cinematic is playing (one at a time, no re-entry).
var _berthing := false
var _scolding := false   # the one-time scrape lesson is open; don't re-trigger


func _ready() -> void:
	add_to_group("dock_pads")


func _process(_delta: float) -> void:
	queue_redraw()


## Direction of a correct approach, world-space (into the slot).
func approach_dir() -> Vector2:
	return -global_transform.x.normalized()


func status_for(ship: BuildShip) -> Dictionary:
	var speed := ship.velocity.length()
	var creeping := speed < CREEP_SPEED
	var angle_err := 0.0
	if not creeping:
		angle_err = clampf(
			absf(rad_to_deg(ship.velocity.angle_to(approach_dir()))) / 90.0, 0.0, 1.5)
	var speed_err := maxf(0.0, speed - SPEED_LIMIT) / 220.0
	return {
		"in_range": ship.global_position.distance_to(global_position) \
			<= DOCK_RANGE * global_scale.x,
		"angle_ok": angle_err < 0.35,
		"speed_ok": speed <= SPEED_LIMIT,
		"error": clampf(0.65 * angle_err + 0.35 * speed_err, 0.0, 1.5),
	}


func try_dock(ship: TestShip) -> void:
	var s := status_for(ship)
	if not s.in_range:
		return
	# SIZE LIMIT: the berth is only so big. A hull too large for it never gets a
	# clearance — bounced gently at the mouth. This is why the Reach is all small
	# ships: its one station can't take a heavy. (Land a big hull on the planet.)
	# SIZE FLOOR/CAP: a berth is only so big, and a DRYDOCK is only for the big hulls
	# a bay can't take. Both refusals share one gate (size_permitted) so it stays
	# testable; the message just names which way you missed.
	if ship.build != null and ship.build.hull != null \
			and not size_permitted(ship.build.hull.size_band):
		ship._flash_note("TOO LARGE TO BERTH — this station can't dock a hull this size. Heavies need a bigger port." \
			if ship.build.hull.size_band > max_size_band \
			else "TOO SMALL FOR A DRYDOCK — take a landing bay; the cradles are for capital hulls.")
		ship.velocity = -approach_dir() * 90.0 + ship.velocity.bounce(approach_dir()) * 0.2
		Sfx.play_at("scrape", ship.global_position, -8.0, 0.5)
		return
	# OUTLAW LOCKOUT: a pilot the Guardians want dead doesn't get clearance. The
	# station closes; the neutral PLANET is your fallback (and where you mend it).
	if Standing.is_kos("guardian"):
		ship._flash_note("DOCKING DENIED — the Guardians won't clear an outlaw. Head for the planet.")
		ship.velocity = -approach_dir() * 120.0 + ship.velocity.bounce(approach_dir()) * 0.2
		Sfx.play_at("scrape", ship.global_position, -6.0, 0.5)
		return
	# GRADE the approach, then resolve. AGENCY RULE (2026-07-22, user): a
	# NON-FATAL outcome NEVER takes the wheel — not even the first time. You
	# cannot learn a hands-on skill by watching the game fly for you, and having
	# control seized on a dock you basically made reads as broken. Green and
	# yellow resolve instantly; yellow names its fault in a flash so the lesson
	# survives without the cinematic.
	#
	# Only a CRASH still plays the beat — there the ship is already wrecked, so
	# the cinematic is the consequence rather than a hand on the stick.
	var tier := "red" if s.error >= CRASH_ERROR \
		else ("yellow" if s.error > SCRAPE_FREE_ERROR else "green")
	if tier != "red":
		# A scrape on the FIRST berth stops the world and says so. Neither of the
		# quieter options worked: _flash_note draws on the flight HUD, which
		# docking hides the same frame, and a line in the Landing Bay is a wall
		# of text nobody reads when they were expecting to just... dock.
		# So: Ruel hails, the player dismisses him, THEN we berth. Once, ever.
		if tier == "yellow" and not SaveGame.docking_taught:
			_scold_then_dock(ship, s)
			return
		ship.approach_fault = ("SCRAPED IN — %s" % _fault_line(s)) if tier == "yellow" else ""
		_resolve(ship, s, tier)
		return
	# FIRST WRECK: frame it before you watch it. The crash beat on its own reads
	# as the game snatching the stick for no stated reason; with Ruel's call in
	# front of it, the same footage becomes the consequence of a named mistake.
	if not SaveGame.crash_taught:
		_brace_then_crash(ship, s)
		return
	_run_berth(ship, s, tier)


## THE ONE SCRAPE LESSON. Held modal so it cannot be missed, and the berth only
## completes when the player dismisses it — the ship is already stopped at the
## arm, so nothing is taken out of their hands. Fires once and never again:
## `docking_taught` is set the moment it shows, whatever the pilot does next.
func _scold_then_dock(ship: TestShip, s: Dictionary) -> void:
	if _scolding:
		return
	_scolding = true
	SaveGame.docking_taught = true    # taught by the mistake; never repeat it
	# HELD while the message is read: `cinematic` freezes the hull's physics, so
	# a drifting ship can't wander into the arm behind the dialogue.
	ship.cinematic = true
	ship.velocity = Vector2.ZERO

	var line := "Harbormaster Ruel's voice fills the cockpit, dry as dock dust. "
	line += "\"Easy! Easy. You just put paint on my docking arm.\"\n\n"
	line += "%s\n\n" % _fault_line(s)
	line += "\"She'll buff out — and the yard will bill you for it. "
	line += "Here's the only trick that matters, so hear it once: "
	line += "under twenty-five, you can come in at ANY angle and she'll take you. "
	line += "Every time. Nobody ever bent a hull going too gently.\"\n\n"
	line += "\"Now bring her in. I've got the clamps.\""

	var nodes := {"start": {"text": line,
		"choices": [{"text": "Understood, Harbormaster.", "next": "end", "style": "primary"}]}}
	Comms.post("ruel", "Docking Control", line)
	var panel := DialoguePanel.new("ruel", nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = "dock_scrape"   # audio/vo/dock_scrape_start.mp3
	panel.closed.connect(func() -> void:
		_scolding = false
		if is_instance_valid(ship) and not ship.dead:
			ship.cinematic = false
			ship.velocity = Vector2.ZERO
			ship.approach_fault = "SCRAPED IN — %s" % _fault_line(s)
			_resolve(ship, s, "yellow"))
	ship.get_parent().add_child(panel)


## THE ONE WRECK LESSON — shown BEFORE the crash beat, then the beat plays. The
## cinematic was never the problem; arriving with no explanation was. Named
## fault first, consequence second, and the pilot presses the button that starts
## it, so even the cutscene is something they chose to watch.
func _brace_then_crash(ship: TestShip, s: Dictionary) -> void:
	if _scolding:
		return
	_scolding = true
	SaveGame.crash_taught = true
	ship.cinematic = true   # held until they press the button that starts it
	ship.velocity = Vector2.ZERO

	var line := "Ruel is already shouting over the channel, and behind him an "
	line += "alarm is going.\n\n\"ABORT — ABORT! You're coming in like a thrown "
	line += "rock and my crews are on that arm!\"\n\n"
	line += "%s\n\n" % _fault_line(s)
	line += "\"Clamps can't catch what you just did. She's going to bounce, "
	line += "she's going to hurt, and the yard is going to bill you for every "
	line += "centimetre of it.\"\n\nA breath. Lower.\n\n"
	line += "\"Take her round again. Under twenty-five and she'll berth at any "
	line += "angle you like — that's the whole secret. There's no prize for "
	line += "arriving fast, pilot. Only for arriving.\""

	var nodes := {"start": {"text": line,
		"choices": [{"text": "Brace for impact.", "next": "end", "style": "primary"}]}}
	Comms.post("ruel", "Docking Control", line)
	var panel := DialoguePanel.new("ruel", nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = "dock_crash"    # audio/vo/dock_crash_start.mp3
	panel.closed.connect(func() -> void:
		_scolding = false
		if is_instance_valid(ship) and not ship.dead:
			ship.cinematic = false   # _run_berth takes the helm from here
			_run_berth(ship, s, "red"))
	ship.get_parent().add_child(panel)


## The scored outcome, applied. Shared by the instant path and the cinematic.
func _resolve(ship: TestShip, s: Dictionary, tier: String) -> void:
	if tier == "red":
		Sfx.play_at("scrape", ship.global_position, -3.0, 0.65)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE)
		# Rejected: thrown back out of the slot mouth.
		ship.velocity = -approach_dir() * 160.0 + ship.velocity.bounce(approach_dir()) * 0.2
		return
	if tier == "yellow":
		Sfx.play_at("scrape", ship.global_position, -8.0)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE * 0.45)
	if not ship.dead:
		Sfx.play("dock", -8.0)
		ship.dock(self)
		if tier == "green":
			SaveGame.docking_taught = true   # she can fly; stop narrating it


## Name the fault, not just the outcome — a vague scrape teaches nothing. The
## status already knows WHICH check failed, so say it out loud.
func _fault_line(s: Dictionary) -> String:
	if not s.speed_ok and not s.angle_ok:
		return "Too hot AND crooked — ease off and line up on the lane!"
	if not s.speed_ok:
		return "Whoa — slow down, pilot! You're coming in too hot."
	return "Line her up! You're crooked to the lane."


## The berthing beat: control handed to the pad, comms callouts, and the ship
## flown in (or into the wall) so the grade is something you SEE, not a number
## that happened to you.
func _run_berth(ship: TestShip, s: Dictionary, tier: String) -> void:
	if _berthing:
		return
	_berthing = true
	ship.cinematic = true
	ship.velocity = Vector2.ZERO
	ship._flash_note("DOCKING PROCEDURES INITIATED…")
	Sfx.play("click", -10.0, 0.9)
	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(ship) or ship.dead:
		_berthing = false
		return

	var start := ship.global_position
	var berth := global_position
	if tier == "green":
		ship._flash_note("\"Bringing her in.\"")
		await _glide(ship, start, berth, 1.25)
		ship._flash_note("CONTROL: \"Copy that. Well done, pilot.\"")
		Sfx.play("jingle", -12.0, 1.1)
	elif tier == "yellow":
		ship._flash_note("\"Bringing her in.\"   CONTROL: \"%s\"" % _fault_line(s))
		await _glide(ship, start, berth, 1.15, true)
		ship._flash_note("CONTROL: \"Ooof. That repair's going to cost you.\"")
	else:
		ship._flash_note("\"Bringing her—  aaargh!\"")
		# NOT into the berth: a wreck overshoots the clear slot entirely and
		# buries itself in the BACK WALL of the bay, at a different spot every
		# time. Sailing neatly into the one safe point looked like a successful
		# dock that merely happened to explode.
		await _glide(ship, start, _crash_point(ship), 0.45)
		Sfx.play_at("explosion", ship.global_position, -4.0, 0.9)
		Projectile.spark(get_parent(), ship.global_position, Color(1.0, 0.6, 0.3), 22)
		ship._flash_note("CONTROL: \"…Medical to the apron. Again.\"")

	ship.cinematic = false
	_resolve(ship, s, tier)
	_berthing = false


## Where a wreck actually lands: a RANDOM point on the bay's back wall, found by
## raycasting past the berth into the station's own module bodies. Raycast
## rather than a fixed offset so the ship strikes the VISIBLE hull wherever the
## modules happen to sit — the station is composited from parts, so a guessed
## depth would sometimes stop short in open space or punch through a gap.
##
## Each attempt slides the ray sideways, so repeat crashes hit different plating.
func _crash_point(ship: TestShip) -> Vector2:
	var dir := approach_dir()
	var perp := Vector2(-dir.y, dir.x)
	var scale_x: float = maxf(0.01, global_scale.x)
	var space := get_world_2d().direct_space_state
	for attempt in 8:
		var lateral := randf_range(-1.0, 1.0) * 95.0 * scale_x
		var from := global_position + perp * lateral - dir * 24.0 * scale_x
		var query := PhysicsRayQueryParameters2D.create(from, from + dir * 700.0 * scale_x)
		query.exclude = [ship.get_rid()]
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit.position
	# Nothing solid behind the berth (odd station layout): overshoot anyway, so
	# the wreck still ends up somewhere other than the tidy landing point.
	return global_position + dir * 240.0 * scale_x \
		+ perp * randf_range(-1.0, 1.0) * 80.0 * scale_x


## Fly the hull from `a` to `b` over `secs`. `rough` adds a scraping judder and
## sparks along the way — the hull grinding down the slot wall.
func _glide(ship: TestShip, a: Vector2, b: Vector2, secs: float, rough := false) -> void:
	var face := (b - a).angle() if a.distance_to(b) > 1.0 else ship.rotation
	var t := 0.0
	while t < secs and is_instance_valid(ship) and not ship.dead:
		var d: float = get_process_delta_time()
		t += d
		var k: float = clampf(t / secs, 0.0, 1.0)
		var p := a.lerp(b, k)
		if rough:
			p += Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
			if randf() < 0.25:
				Sfx.play_at("scrape", p, -14.0, randf_range(0.8, 1.2))
				Projectile.spark(get_parent(), p, Color(1.0, 0.75, 0.4), 3)
		ship.global_position = p
		ship.rotation = rotate_toward(ship.rotation, face, 3.0 * d)
		ship.velocity = Vector2.ZERO
		await get_tree().process_frame


func undock_exit(ship: TestShip) -> void:
	ship.global_position = global_position
	ship.rotation = (-approach_dir()).angle()
	ship.velocity = -approach_dir() * 140.0


func _draw() -> void:
	var player := get_tree().get_first_node_in_group("player_ship") as TestShip
	if player == null or player.docked_at != null:
		return
	if player.global_position.distance_to(global_position) > UI_RANGE:
		return
	var s := status_for(player)
	var color := Color(0.35, 0.9, 0.45) if (s.angle_ok and s.speed_ok) \
		else (Color(0.95, 0.75, 0.3) if s.error < CRASH_ERROR else Color(0.95, 0.3, 0.25))
	# Approach chevrons along local +X, pointing inward (direction of travel).
	for i in 4:
		var x := 34.0 + 26.0 * i
		draw_line(Vector2(x + 9, -8), Vector2(x, 0), color, 1.5)
		draw_line(Vector2(x + 9, 8), Vector2(x, 0), color, 1.5)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, color, 1.5)

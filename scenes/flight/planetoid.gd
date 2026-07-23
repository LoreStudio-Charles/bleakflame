class_name Planetoid
extends Node2D
## Small in-world body (real planets will be backdrop + approach zones; this
## is the sandbox-scale stand-in). Owns a gravity well and the landing skill
## check: ride gravity down through the landing band with velocity pointed
## into the descent and speed under the re-entry limit, then commit with E.
## Hitting the surface without landing is a crash — for pirates too.

# Radii match the sprite: 112px drawn radius x 4 integer upscale. These are the
# BASE (mult=1) radii; a bigger body scales them by `radius_mult` — see the
# instance `surface_r`/`band_r`/`grav_r` set in _ready, which the physics uses.
const MULT := 8
const SPRITE_SCALE := MULT
const SURFACE_R := 112.0 * MULT
const BAND_R := 155.0 * MULT
const GRAV_R := 260.0 * MULT
const GRAV_ACCEL := 160.0   # px/s^2 at the surface, fading toward grav_r
const REENTRY_SPEED := 150.0
const CRASH_ERROR := 0.72
const SCRAPE_FREE_ERROR := 0.18
const CRASH_DAMAGE_SCALE := 260.0
const SURFACE_CRASH_DAMAGE := 110.0

## Size + role knobs so ONE class serves the fringe colony (Epharon, the tuned
## landing tutorial) AND the capital (Orivel, 3x, a gravity landmark you can't
## land at YET). `radius_mult` scales every radius off the base consts; `landable`
## gates the landing minigame + band (the well + surface collider always apply, so
## a not-yet-landable world still pulls you in and can't be flown through).
@export var radius_mult := 1.0
@export var landable := true
@export var sprite_path := "res://assets/world/planetoid.png"

## Instance radii, = the base consts * radius_mult (set in _ready). The physics
## and _draw read THESE, not the consts, so a scaled body wells and crashes at its
## own drawn size. External code that only ever meant Epharon may still read the
## consts (they equal the mult=1 values).
var surface_r := SURFACE_R
var band_r := BAND_R
var grav_r := GRAV_R

## How much room AI ships give the planet (BuildShip.separation_dir). Set beyond
## the GRAVITY WELL so they steer clear BEFORE the pull can grab them — "safety
## first" at the planet (user, 2026-07-22). Generous on purpose: the AI have no
## business near the well, only the player lands. Set in _ready off grav_r.
var avoid_radius := GRAV_R * 1.9   # ~3950 at mult=1; recomputed in _ready


func _ready() -> void:
	add_to_group("planetoids")
	surface_r = SURFACE_R * radius_mult
	band_r = BAND_R * radius_mult
	grav_r = GRAV_R * radius_mult
	avoid_radius = grav_r * 1.9
	var sprite := Sprite2D.new()
	sprite.texture = load(sprite_path)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * radius_mult
	add_child(sprite)


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	for group in ["player_team", "hostile_team"]:
		for node in get_tree().get_nodes_in_group(group):
			var ship := node as BuildShip
			if ship == null or ship.dead or ship.get("docked_at") != null:
				continue
			# A ship HELD by a scripted beat is exempt — gravity must not keep
			# pulling (nor the surface keep hitting it) while a modal has the
			# screen or a cinematic is flying it. Without this the hard-set-down
			# lesson was a death sentence: the pull accumulated behind the
			# dialogue and drove the hull into the planet while it was being read.
			if ship.get("cinematic") == true:
				continue
			var to_center := global_position - ship.global_position
			var dist := to_center.length()
			if dist > grav_r:
				continue
			var pull := GRAV_ACCEL * clampf(1.0 - (dist - surface_r) / (grav_r - surface_r), 0.25, 1.0)
			ship.velocity += to_center.normalized() * pull * delta
			if dist < surface_r + ship.hit_radius:
				Sfx.play_at("scrape", ship.global_position, -4.0, 0.6)
				ship.take_damage(SURFACE_CRASH_DAMAGE)
				# Live telemetry: an AI hitting the surface is the exact thing the
				# planet-avoidance fix was meant to end. A WARN here that keeps
				# firing means the berth needs widening; silence means it worked.
				var who := "player" if ship.is_in_group("player_ship") \
					else (ship.build.hull.display_name if ship.build != null else "AI")
				var role := "guardian" if ship.is_in_group("player_team") \
					else ("trader" if ship.is_in_group("traders") else "pirate")
				Telemetry.warn("planet", "%s (%s) crashed the surface" % [who, role])
				if not ship.dead:
					var out := -to_center.normalized()
					ship.global_position = global_position + out * (surface_r + ship.hit_radius + 6.0)
					ship.velocity = ship.velocity.bounce(out) * 0.3 + out * 90.0


func status_for(ship: BuildShip) -> Dictionary:
	var to_center := global_position - ship.global_position
	var dist := to_center.length()
	var speed := ship.velocity.length()
	var descending := ship.velocity.dot(to_center) > 0.0
	var angle_err := 1.5
	if speed > 1.0:
		angle_err = clampf(
			absf(rad_to_deg(ship.velocity.angle_to(to_center))) / 90.0, 0.0, 1.5)
	var speed_err := maxf(0.0, speed - REENTRY_SPEED) / 180.0
	return {
		"in_band": dist > surface_r and dist <= band_r,
		"descending": descending,
		"angle_ok": angle_err < 0.35,
		"speed_ok": speed <= REENTRY_SPEED,
		"error": clampf(0.55 * angle_err + 0.45 * speed_err, 0.0, 1.5),
	}


## True while a landing cinematic is playing (one at a time, no re-entry).
var _landing := false
var _scolding := false   # the one-time hard-set-down lesson is open


func try_land(ship: TestShip) -> void:
	# Not-yet-landable worlds (Orivel) still well + collide, but there is no berth
	# to set down at — a clear refusal, never a silent no-op (visibility rule).
	if not landable:
		ship._flash_note("NO CLEARANCE — this world has no berth for you")
		return
	var s := status_for(ship)
	if not s.in_band:
		return
	# Same AGENCY RULE as the station (2026-07-22, user): a non-fatal set-down
	# NEVER takes the wheel, first time or not — the descent is a hands-on skill
	# and seizing control mid-landing reads as broken. Yellow names its fault in
	# a flash instead. Only a CRATER still plays, where the ship is already lost.
	var tier := "red" if s.error >= CRASH_ERROR \
		else ("yellow" if s.error > SCRAPE_FREE_ERROR else "green")
	if tier != "red":
		# First hard set-down gets the modal lesson, same as the station's scrape
		# (a flash on the flight HUD is wiped the frame landing hides it, and
		# text in the Landing Bay goes unread). Imari says it, once, ever.
		if tier == "yellow" and not SaveGame.landing_taught:
			_scold_then_land(ship, s)
			return
		ship.approach_fault = ("HARD SET-DOWN — %s" % _fault_line(s)) if tier == "yellow" else ""
		_resolve_landing(ship, s, tier)
		return
	# FIRST CRATER: Imari frames it, then the descent beat plays. Same reasoning
	# as the station — the cinematic is fine, arriving at it unexplained is not.
	if not SaveGame.crater_taught:
		_brace_then_crater(ship, s)
		return
	_run_landing(ship, s, tier)


## The one hard-set-down lesson, modal, before the ship is put down. The descent
## is already over and the hull is stopped, so nothing is taken out of the
## player's hands — they dismiss Imari and the landing completes.
func _scold_then_land(ship: TestShip, s: Dictionary) -> void:
	if _scolding:
		return
	_scolding = true
	SaveGame.landing_taught = true    # taught by the mistake; never repeat it
	# HELD, not merely stopped: `cinematic` freezes the hull's own physics AND
	# exempts it from the gravity well above, so the descent genuinely pauses
	# while the message is read. Zeroing velocity alone was not enough — gravity
	# simply started pulling again the next frame.
	ship.cinematic = true
	ship.velocity = Vector2.ZERO

	var line := "Imari comes on the channel before the dust has settled. "
	line += "\"Ohh, that one we FELT. Struts are still ringing.\"\n\n"
	line += "%s\n\n" % _fault_line(s)
	line += "\"No harm done that credits won't fix. But listen — a planet is "
	line += "always pulling you down, so your only job on the way in is to slow "
	line += "the fall. Come down TOWARD the pad, not sliding across it, and if "
	line += "you're ever unsure, bleed off more speed. Gravity is patient. "
	line += "It'll wait for you.\"\n\n"
	line += "\"Now set her down properly and come have a drink.\""

	var nodes := {"start": {"text": line,
		"choices": [{"text": "Understood, Elder.", "next": "end", "style": "primary"}]}}
	Comms.post("imari", "Colony Approach", line)
	var panel := DialoguePanel.new("imari", nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = "land_hard"     # audio/vo/land_hard_start.mp3
	panel.closed.connect(func() -> void:
		_scolding = false
		if is_instance_valid(ship) and not ship.dead:
			ship.cinematic = false
			ship.velocity = Vector2.ZERO
			ship.approach_fault = "HARD SET-DOWN — %s" % _fault_line(s)
			_resolve_landing(ship, s, "yellow"))
	ship.get_parent().add_child(panel)


## The one crater lesson, shown BEFORE the descent beat. Gravity is the thing a
## new pilot never accounts for, so Imari names it out loud before they watch it
## win.
func _brace_then_crater(ship: TestShip, s: Dictionary) -> void:
	if _scolding:
		return
	_scolding = true
	SaveGame.crater_taught = true
	ship.cinematic = true   # held clear of gravity while the warning is read
	ship.velocity = Vector2.ZERO

	var line := "Imari's voice cuts in, sharp in a way you haven't heard "
	line += "before.\n\n\"PULL UP. Pull UP, pilot — you are not landing, you "
	line += "are FALLING.\"\n\n"
	line += "%s\n\n" % _fault_line(s)
	line += "\"The ground doesn't move. It has never once moved for anybody. "
	line += "Whatever speed you carry into it is the speed it hands straight "
	line += "back to your hull.\"\n\nA pause, and the anger goes out of it.\n\n"
	line += "\"Bleed it off on the way down. All of it. A landing is just a "
	line += "fall you talked out of happening — take as long as you need.\""

	var nodes := {"start": {"text": line,
		"choices": [{"text": "Brace for impact.", "next": "end", "style": "primary"}]}}
	Comms.post("imari", "Colony Approach", line)
	var panel := DialoguePanel.new("imari", nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = "land_crater"   # audio/vo/land_crater_start.mp3
	panel.closed.connect(func() -> void:
		_scolding = false
		if is_instance_valid(ship) and not ship.dead:
			ship.cinematic = false   # _run_landing takes the helm from here
			_run_landing(ship, s, "red"))
	ship.get_parent().add_child(panel)


func _resolve_landing(ship: TestShip, s: Dictionary, tier: String) -> void:
	if tier == "red":
		Sfx.play_at("scrape", ship.global_position, -3.0, 0.6)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE)
		if not ship.dead:
			var out := (ship.global_position - global_position).normalized()
			ship.velocity = out * 220.0
		return
	if tier == "yellow":
		Sfx.play_at("scrape", ship.global_position, -8.0, 0.8)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE * 0.4)
	if not ship.dead:
		Sfx.play("dock", -8.0, 0.9)
		ship.dock(self)
		if tier == "green":
			SaveGame.landing_taught = true


## A descent names its fault too — coming in flat is the landing-specific sin
## (you want to drop TOWARD the surface, not skim across the band).
func _fault_line(s: Dictionary) -> String:
	if not s.speed_ok and not s.angle_ok:
		return "Too fast and too flat — bleed speed and drop straight in!"
	if not s.speed_ok:
		return "Slow your descent! You'll burn up on re-entry."
	return "You're coming in flat — bring her nose down toward the pad."


func _run_landing(ship: TestShip, s: Dictionary, tier: String) -> void:
	if _landing:
		return
	_landing = true
	ship.cinematic = true
	ship.velocity = Vector2.ZERO
	ship._flash_note("LANDING PROCEDURES INITIATED…")
	Sfx.play("click", -10.0, 0.9)
	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(ship) or ship.dead:
		_landing = false
		return

	var start := ship.global_position
	# Set down just above the surface, on the bearing she approached from.
	var bearing := (start - global_position).normalized()
	var pad := global_position + bearing * (surface_r + 6.0)
	if tier == "green":
		ship._flash_note("\"Bringing her down.\"")
		await _descend(ship, start, pad, 1.35)
		ship._flash_note("COLONY: \"Touchdown. Nicely flown, pilot.\"")
		Sfx.play("jingle", -12.0, 1.1)
	elif tier == "yellow":
		ship._flash_note("\"Bringing her down.\"   COLONY: \"%s\"" % _fault_line(s))
		await _descend(ship, start, pad, 1.2, true)
		ship._flash_note("COLONY: \"Ooof. Hope you kept the receipts — that'll cost you.\"")
	else:
		ship._flash_note("\"Bringing her—  aaargh!\"")
		await _descend(ship, start, pad, 0.5)
		Sfx.play_at("explosion", ship.global_position, -4.0, 0.85)
		Projectile.spark(get_parent(), ship.global_position, Color(1.0, 0.6, 0.3), 22)
		ship._flash_note("COLONY: \"…we felt that one from the greenhouse.\"")

	ship.cinematic = false
	_resolve_landing(ship, s, tier)
	_landing = false


func _descend(ship: TestShip, a: Vector2, b: Vector2, secs: float, rough := false) -> void:
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
				Projectile.spark(get_parent(), p, Color(1.0, 0.72, 0.4), 3)
		ship.global_position = p
		ship.rotation = rotate_toward(ship.rotation, face, 3.0 * d)
		ship.velocity = Vector2.ZERO
		await get_tree().process_frame


func undock_exit(ship: TestShip) -> void:
	var out := (ship.global_position - global_position).normalized()
	if out.length_squared() < 0.5:
		out = Vector2.RIGHT
	ship.global_position = global_position + out * (surface_r + 40.0)
	ship.rotation = out.angle()
	ship.velocity = out * 220.0


func _draw() -> void:
	# Body is the sprite; only the landing band + gravity rings are drawn,
	# colored by the player's current approach.
	# The gravity ring always draws (the well is real on every body); the LANDING
	# BAND only on a landable world, so Orivel reads as "pull, but no berth".
	if landable:
		var band_color := Color(0.6, 0.6, 0.7, 0.35)
		var player := get_tree().get_first_node_in_group("player_ship") as TestShip
		if player != null and player.docked_at == null \
				and player.global_position.distance_to(global_position) < grav_r + 300.0:
			var s := status_for(player)
			if s.in_band:
				band_color = Color(0.35, 0.9, 0.45, 0.6) if (s.angle_ok and s.speed_ok) \
					else (Color(0.95, 0.75, 0.3, 0.6) if s.error < CRASH_ERROR else Color(0.95, 0.3, 0.25, 0.6))
		draw_arc(Vector2.ZERO, band_r, 0, TAU, 64, band_color, 2.0)
	draw_arc(Vector2.ZERO, grav_r, 0, TAU, 64, Color(0.5, 0.5, 0.65, 0.18), 1.5)

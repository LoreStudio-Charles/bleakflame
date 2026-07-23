class_name Cinderweb
extends Leviathan
## The Cinderweb: this system's leviathan — a named shadow demon patrolling
## an eccentric orbit beyond the planet and station. When its path swings
## near and it catches sight of a ship in open space, it hunts; those moments
## should feel hopeless and end in destruction or flight. It will not pursue
## prey into the station's protected airspace. Driven to 0 HP it disgorges
## its hoard and RETREATS (the leviathan mortality rule — see Leviathan);
## it only truly dies at the campaign's end, when `mortal` is set.
## Not a BuildShip: it is not made of components. It is made of appetite.

const BEAST_NAME := "Cinderweb"

const HP_MAX := 6000.0
const SPRITE_SCALE := 2.0

const ORBIT_CENTER := Vector2(4200, 2600)
const ORBIT_A := 7800.0
const ORBIT_B := 3200.0
const ORBIT_TILT := 0.55
const ORBIT_PERIOD := 480.0    # one lap ~8 minutes: an occasional terror
const ORBIT_SPEED := 170.0

const GAZE_RANGE := 1500.0
const HUNT_SPEED := 380.0      # a fighter can still flee, but only just
const BREAK_CHASE_RANGE := 2800.0
const STATION_SAFE_RADIUS := 1800.0

## SIMULATED HUNGER: between passes at the player, the ambient beast preys on
## lane HAULERS — traceless, so the world fills with vanished ships and clipped
## distress calls. This IS the campaign's missing-hauler mystery, happening live
## in the sim (Voss's "no debris"). Ambient orbiter only (ambush/scripted skip it).
const HUNGER_RANGE := 3600.0        # how far off its orbit it will range to feed
const HUNGER_MIN := 45.0            # seconds between feeds
const HUNGER_MAX := 95.0
const HUNGER_DEVOUR_RANGE := 140.0  # close enough to swallow a hauler whole
const DISTRESS_RANGE := 3800.0      # the player must be this near to catch the doomed call
## Distress fragments — each cut off mid-word (the transmission dies into static).
const DISTRESS_LINES := [
	"Mayday, mayday — something's on our hull, it's",
	"—power's gone, all of it, it's right outside the",
	"No — no no, it's got us, it's pulling us",
	"Anyone on this band, please, we are being",
	"There's something in the dark out here, it's",
	"Cargo bay's gone black, hull's breached — oh god it's",
]

## The DEVOUR is a heavy BITE, not a chip-grind: a single chunky hit on a
## slow beat, so it reads as a distinct, dreadful event. A level-1 hull
## survives two or three (panic, then flee); it's a real spike of damage to a
## veteran returning to end it. Terror is a rhythm, not a DPS number.
const BITE_RANGE := 185.0
const BITE_DAMAGE := 55.0
const BITE_INTERVAL := 1.8
const LANCE_RANGE := 1000.0

## The POUNCE: from mid-range it LEAPS the gap in a heartbeat, bringing teeth
## and tendrils to bear before you can react. Long cooldown — one or two
## lunges in a fight, each a fresh jolt of panic.
const POUNCE_CD := 10.0
const POUNCE_DUR := 0.55
const POUNCE_SPEED := 1050.0
const POUNCE_BAND_MIN := 560.0
const POUNCE_BAND_MAX := 1500.0

## Umbral Breath: mid-range volley of ensnaring shadow (BreathCloud). The
## trap that turns flight into a mistake you made three seconds ago. Open-
## world it exhales often — the real terror, saved for players who choose it.
const BREATH_RANGE := 520.0
const BREATH_CD := 5.0

## THE DEVOUR — the maw closes. Ensnared by the Umbral Breath and pulled into
## the beast's core, a ship cannot burn free before the jaws shut: it is
## swallowed whole. A true one-shot (the old Wingfeather legend), but an
## AVOIDABLE one — dodge the telegraphed breath and you are only ever bitten,
## never devoured. A short wind-up telegraphs the closing jaws. Open-world
## beast ONLY; the survivable ambush glimpse (no breath) can never devour.
const DEVOUR_RANGE := 95.0
const DEVOUR_WINDUP := 0.45
## Inside this radius you are INSIDE the incorporeal body — the dark clings
## like its breath and ensnares you, which feeds the devour above.
const CORE_ENSNARE_RADIUS := 130.0

## The hoard: what vengeance pays. Disgorged whether it is driven off (0 HP,
## retreats) or finally slain (mortal) — so hunting it is worth it long
## before it can be ended.
const HOARD := [
	"res://data/components/defense/aegis_composite.tres",
	"res://data/components/reactors/overdrive_bottle.tres",
	"res://data/components/weapons/twinlance_pulse.tres",
	"res://data/components/engines/afterjet_sprint.tres",
]

var hunting := false
var _hunger_cd := 30.0             # first feed a little after the run begins
var _hunger_prey: BuildShip = null # the hauler the beast is stalking between player passes
## Ambush mode (scripted beat 3): spawned near the player, already hunting,
## and — unlike the ambient orbiter — it FOLDS BACK INTO THE DARK the moment
## the prey escapes, instead of drifting home to its orbit. It is also
## DELIBERATELY WEAKER than the open-world beast: a survivable glimpse, not
## the real thing. The open-world Cinderweb out in the dark is far deadlier
## (full lethality, snaring Umbral Breath, full hunt speed) — the event is
## the trailer, the orbiter is the film.
var ambush := false
var lethality := 1.0           # ambush scales this down; contact/lance obey it
var _hunt_speed := HUNT_SPEED
var _retreating := false
var _lash_cd := 0.0            # ambush only: the reach that unmakes escorts

## Aseprite pipeline, three drop-in folders (kept under leviathan_* for now):
##   leviathan_anim/  — the BREATHING loop (always-on).
##   leviathan_blink/ — optional: one breath cycle WITH the blink.
##   leviathan_enraged/ — optional: the HUNTING loop ("unblinking fury").
const ANIM_DIR := "res://assets/world/leviathan_anim"
const BLINK_DIR := "res://assets/world/leviathan_blink"
const ENRAGED_DIR := "res://assets/world/leviathan_enraged"
const ANIM_FPS := 7.0

## Ethereal veil: the breath's own smoke textures drift and spiral OVER the
## body, so the beast reads as half-here — a web of smoke and eyes, not solid.
const VEIL_DIR := "res://assets/world/breath"
static var _veil_pool: Array[Texture2D] = []
static var _veil_loaded := false

var _t := randf() * TAU
var _lance: WeaponDef
var _lance_cd := 0.0
var _bite_cd := 0.0
var _pounce_cd := POUNCE_CD * 0.5   # can pounce fairly soon after it commits
var _pounce_t := 0.0
var _devour_t := 0.0                # >0 while the maw is closing on snared prey
var _breath_cd := 0.0
var _sprite: Node2D
var _veil: Node2D
var _veil_layers: Array = []
var _animated: AnimatedSprite2D
var _has_blink := false
var _has_enraged := false
var _breaths_until_blink := 0


func _ready() -> void:
	beast_name = BEAST_NAME
	hp = HP_MAX
	max_hp = HP_MAX
	add_to_group("hostile_team")
	add_to_group("leviathan")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# Aseprite pipeline: export a PNG sequence into leviathan_anim/ (any
	# sorted filenames) and the beast animates; otherwise the static sprite.
	var frames := _anim_frames(ANIM_DIR)
	if not frames.is_empty():
		var sprite_frames := SpriteFrames.new()
		sprite_frames.remove_animation("default")
		sprite_frames.add_animation("breathe")
		sprite_frames.set_animation_speed("breathe", ANIM_FPS)
		sprite_frames.set_animation_loop("breathe", true)
		for path in frames:
			sprite_frames.add_frame("breathe", load(path))
		var blink_frames := _anim_frames(BLINK_DIR)
		_has_blink = not blink_frames.is_empty()
		if _has_blink:
			sprite_frames.add_animation("blink")
			sprite_frames.set_animation_speed("blink", ANIM_FPS)
			sprite_frames.set_animation_loop("blink", false)
			for path in blink_frames:
				sprite_frames.add_frame("blink", load(path))
		var enraged_frames := _anim_frames(ENRAGED_DIR)
		_has_enraged = not enraged_frames.is_empty()
		if _has_enraged:
			sprite_frames.add_animation("enraged")
			sprite_frames.set_animation_speed("enraged", ANIM_FPS)
			sprite_frames.set_animation_loop("enraged", true)
			for path in enraged_frames:
				sprite_frames.add_frame("enraged", load(path))
		_animated = AnimatedSprite2D.new()
		_animated.sprite_frames = sprite_frames
		_animated.play("breathe")
		if _has_blink:
			_animated.animation_looped.connect(_on_breath_done)
			_animated.animation_finished.connect(_on_blink_done)
			_reset_blink_counter()
		_sprite = _animated
	else:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/world/leviathan.png")
		_sprite = sprite
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.self_modulate.a = 0.62   # ethereal: never fully solid, "not quite here"
	add_child(_sprite)

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	collision.shape = shape
	add_child(collision)
	# INCORPOREAL: ships pass THROUGH the beast — it is a thing of smoke and
	# eyes, not a wall (no more clinging to it). Weapon hits are group +
	# hit_radius based (see Projectile), so fire still lands. Its finale
	# vulnerability comes later, when a light-weapon forces it into our realm.
	collision_layer = 0
	collision_mask = 0

	_build_veil()

	_lance = WeaponDef.new()
	_lance.display_name = "Umbral Lance"
	_lance.damage = 50.0
	_lance.fire_interval = 1.5
	_lance.projectile_speed = 480.0
	_lance.weapon_range = LANCE_RANGE
	_lance.bolt_color = Color(0.72, 0.38, 1.0)   # wrong-colored light
	_lance.bolt_scale = 1.6

	global_position = _orbit_point(_t)


## Wreathe the body in slow, spiralling smoke — the breath's textures, faint
## and violet, orbiting and self-rotating over the beast so it never reads as
## solid. Drop-in art (assets/world/breath); no art = no veil, never a crash.
func _build_veil() -> void:
	if not _veil_loaded:
		_veil_loaded = true
		var da := DirAccess.open(VEIL_DIR)
		if da != null:
			for f in da.get_files():
				var fn := f.trim_suffix(".import")
				if fn.ends_with(".png"):
					var p := "%s/%s" % [VEIL_DIR, fn]
					if ResourceLoader.exists(p):
						_veil_pool.append(load(p))
	if _veil_pool.is_empty():
		return
	_veil = Node2D.new()
	add_child(_veil)   # over _sprite (added earlier), so the smoke rides on top
	var body_r := maxf(hit_radius, 60.0)
	for i in 5:
		var s := Sprite2D.new()
		s.texture = _veil_pool[randi() % _veil_pool.size()]
		var cover := body_r * randf_range(0.75, 1.35)
		var sc := (cover * 2.0) / maxf(float(s.texture.get_width()), 1.0)
		s.scale = Vector2(sc, sc)
		s.modulate = Color(0.72, 0.55, 0.98, randf_range(0.14, 0.26))   # faint violet
		_veil.add_child(s)
		_veil_layers.append({
			"spr": s,
			"spin": randf_range(0.12, 0.4) * (1.0 if randf() < 0.5 else -1.0),
			"orbit_r": body_r * randf_range(0.0, 0.55),
			"orbit_a": randf() * TAU,
			"orbit_speed": randf_range(0.15, 0.5) * (1.0 if randf() < 0.5 else -1.0),
		})


func _anim_frames(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var file_name := f.trim_suffix(".import")
		if file_name.ends_with(".png"):
			var p := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(p) and not out.has(p):
				out.append(p)
	out.sort()
	return out


## Blink pacing: a few breaths apart at rest; while hunting, hardly at all.
func _reset_blink_counter() -> void:
	_breaths_until_blink = randi_range(9, 14) if hunting else randi_range(3, 5)


func _on_breath_done() -> void:
	# Only calm breathing blinks; the enraged loop is unblinking fury.
	if _animated.animation != &"breathe":
		return
	_breaths_until_blink -= 1
	if _breaths_until_blink <= 0:
		_animated.play("blink")


func _on_blink_done() -> void:
	_reset_blink_counter()
	_animated.play("enraged" if hunting and _has_enraged else "breathe")


func _set_fury(enraged: bool) -> void:
	if _animated == null or not _has_enraged:
		return
	_animated.play("enraged" if enraged else "breathe")


func _orbit_point(t: float) -> Vector2:
	return ORBIT_CENTER + Vector2(cos(t) * ORBIT_A, sin(t) * ORBIT_B).rotated(ORBIT_TILT)


## Scripted ambush: appears at `pos`, already hunting, already furious — but
## a lesser terror than the one that stalks the open dark, so it can be run
## from and lived through.
static func spawn_ambush(parent: Node, pos: Vector2) -> Cinderweb:
	var lev := Cinderweb.new()
	lev.ambush = true
	lev.lethality = 0.30           # a glimpse, not the reaping (kept survivable
	                               # as the open-world beast grew deadlier)
	lev._hunt_speed = HUNT_SPEED * 0.72   # a fighter can open the gap and flee
	parent.add_child(lev)
	lev.global_position = pos
	lev.hunting = true
	lev._lance.damage *= lev.lethality
	lev.modulate = Color(0.75, 0.72, 0.85, 0.8)   # thinner, half-real
	lev._set_fury(true)
	Sfx.play("dread", -2.0)
	return lev


## Scripted-flee state: the witness set-piece drives the body either along a
## fixed vector (`_flee_vel`, the loom) OR homing on a target (`_chase_target`,
## the aggro chase after Krayt) instead of running the hunt AI. See _physics_process.
var _scripted_flee := false
var _flee_vel := Vector2.ZERO
var _origin := Vector2.ZERO
var _chase_target: Node2D = null
var _chase_speed := 0.0


## A witness set-piece: the beast tears out of the dark on a fixed heading,
## chasing prey that ISN'T you (Krayt drawing it off the falling Shoal), then
## folds away once it's run far. No hunting, no attacks — terror you can only
## watch, and can never catch.
static func spawn_pursuit(parent: Node, pos: Vector2, flee_dir: Vector2, speed: float) -> Cinderweb:
	var lev := Cinderweb.new()
	parent.add_child(lev)
	lev.global_position = pos
	lev._origin = pos
	lev._flee_vel = flee_dir.normalized() * speed
	lev._scripted_flee = true
	lev.hunting = false
	lev._set_fury(true)   # unblinking, enraged — mid-hunt, just not YOUR hunt
	lev.modulate = Color(0.8, 0.76, 0.9, 0.85)
	Sfx.play("dread", -1.0)
	return lev


## A set-piece beast is UNTOUCHABLE: Krayt's fire (and any stray player bolt)
## sparks off it — the projectile still draws its impact — but nothing dents it
## and nothing can make it retreat early, so the scripted chase stays on rails.
## Matches the fiction: you cannot hurt it yet.
func take_damage(amount: float, source: Node = null) -> void:
	if _scripted_flee:
		return
	super(amount, source)


## Fixed-heading drive (the loom): 0 speed = hold in place, a vector = drift that
## way. Clears any chase target.
func drive(dir: Vector2, speed: float) -> void:
	_chase_target = null
	_flee_vel = dir.normalized() * speed


## Aggro chase: HOME on `target` every frame — the beast locks onto Krayt and
## hounds him off, turning to follow his real position instead of flying a
## parallel line beside him. When he's gone, _physics_process folds it away.
func chase(target: Node2D, speed: float) -> void:
	_chase_target = target
	_chase_speed = speed
	_flee_vel = Vector2.ZERO


## The wreath of orbiting smoke, advanced one frame (shared by the hunt loop and
## the scripted flee so the body always looks alive).
func _animate_veil(delta: float) -> void:
	if _veil == null:
		return
	for lyr in _veil_layers:
		lyr.orbit_a += lyr.orbit_speed * delta
		lyr.spr.position = Vector2(cos(lyr.orbit_a), sin(lyr.orbit_a) * 0.6) * lyr.orbit_r
		lyr.spr.rotation += lyr.spin * delta


## Suspend the ambient orbiter during a scripted ambush so the player can
## never blunder into two Cinderwebs at once. Restored when the event ends.
func set_suspended(s: bool) -> void:
	visible = not s
	set_physics_process(not s)
	if s:
		hunting = false


## Fold into the dark — driven off, not slain. No hoard; the player fled.
func retreat() -> void:
	if _retreating:
		return
	_retreating = true
	hunting = false
	Sfx.play_at("dread", global_position, -8.0, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.35, 0.18, 0.5, 0.0), 1.3)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if dead or _retreating:
		return
	# Witness set-piece: no hunt, no attacks — the beast tears past on a fixed
	# vector (chasing prey that isn't you) and folds into the dark once it's run
	# far enough. Returns before ANY targeting logic, so it never touches you.
	if _scripted_flee:
		if _chase_target != null and is_instance_valid(_chase_target) \
				and not bool(_chase_target.get("dead")):
			# Aggro: home on the prey's position — a real chase, not a parallel run.
			var to_t: Vector2 = _chase_target.global_position - global_position
			global_position += to_t.normalized() * minf(_chase_speed * delta, to_t.length())
		elif _flee_vel != Vector2.ZERO:
			global_position += _flee_vel * delta
		else:
			retreat()   # prey gone (fled the field) and no heading left — fold into the dark
			return
		_sprite.rotation += 0.12 * delta
		_animate_veil(delta)
		if _origin.distance_to(global_position) > 4200.0:
			retreat()
		return
	# An ambusher whose prey has slipped its gaze doesn't go home — it leaves.
	if ambush and not hunting:
		retreat()
		return
	_t += TAU / ORBIT_PERIOD * delta
	_lance_cd = maxf(0.0, _lance_cd - delta)
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_pounce_cd = maxf(0.0, _pounce_cd - delta)
	_pounce_t = maxf(0.0, _pounce_t - delta)
	_breath_cd = maxf(0.0, _breath_cd - delta)
	_lash_cd = maxf(0.0, _lash_cd - delta)
	# The escort's fire is futile against 4500 HP; the beast's is not. In an
	# ambush it reaches out and unmakes any guardian that flew to help — they
	# die so the player learns nothing here can be fought, only fled.
	if ambush and _lash_cd <= 0.0:
		_lash_cd = 1.1
		for ally in get_tree().get_nodes_in_group("player_team"):
			if ally is GuardianShip and not ally.dead \
					and global_position.distance_to(ally.global_position) < LANCE_RANGE * 1.2:
				ally.take_damage(120.0)
	_sprite.rotation += 0.12 * delta   # slow, wrong, ceaseless coiling
	_animate_veil(delta)

	var player := get_tree().get_first_node_in_group("player_ship") as TestShip
	var player_exposed := player != null and not player.dead \
		and player.docked_at == null \
		and player.global_position.length() > STATION_SAFE_RADIUS

	var target := _orbit_point(_t)
	var speed := ORBIT_SPEED

	if hunting:
		if not player_exposed \
				or global_position.distance_to(player.global_position) > BREAK_CHASE_RANGE:
			hunting = false   # prey escaped, or reached the guns of home
			_set_fury(false)
		else:
			var dist := global_position.distance_to(player.global_position)
			# Mid-lunge: it hurls itself at the prey's lead, faster than flight.
			if _pounce_t > 0.0:
				target = player.global_position + player.velocity * 0.35
				speed = POUNCE_SPEED
			else:
				target = player.global_position
				speed = _hunt_speed
				# Loose in the mid-range band? Close it in a heartbeat.
				if _pounce_cd <= 0.0 and dist > POUNCE_BAND_MIN and dist < POUNCE_BAND_MAX:
					_start_pounce()
			# The snaring Umbral Breath is what makes the open-world beast a
			# death sentence — the ambush glimpse never brings it.
			if not ambush and dist < BREATH_RANGE and _breath_cd <= 0.0:
				_breath_cd = BREATH_CD
				_exhale(player)
			if dist < LANCE_RANGE and _lance_cd <= 0.0:
				_lance_cd = _lance.fire_interval
				var dir := (player.global_position - global_position).normalized()
				Projectile.spawn(get_tree().current_scene,
					global_position + dir * 95.0, dir, _lance, "player_team")
			# Inside the shadow-body the dark clings like its breath; being ensnared
			# here feeds the devour. Ships pass through the incorporeal beast now, so
			# you CAN end up in its core.
			if not ambush and dist < CORE_ENSNARE_RADIUS:
				player.snared = maxf(player.snared, 0.3)
			# THE DEVOUR: snared prey dragged into the core is swallowed whole.
			# Unsnared ships are only ever bitten (below).
			if not ambush and player.snared > 0.0 and dist < DEVOUR_RANGE:
				_tick_devour(player, delta)
			elif _devour_t > 0.0:
				_release_maw()   # the snare lapsed, or it drifted clear
			# The bite is held while the jaws are already closing to devour.
			if dist < BITE_RANGE + player.hit_radius and _bite_cd <= 0.0 and _devour_t <= 0.0:
				_bite(player)
	elif player_exposed \
			and global_position.distance_to(player.global_position) < GAZE_RANGE:
		hunting = true
		_hunger_prey = null          # the player is the real terror — drop the hauler
		Sfx.play("dread", -1.0)      # the womp that sinks a heart
		_set_fury(true)              # every eye forward, and none of them blink
		if _has_blink:
			_reset_blink_counter()
	else:
		# Idle of the player — so it FEEDS. Simulated hunger: stalk a lane hauler
		# and swallow it traceless. If it has one, it leaves the orbit to close.
		_tick_hunger(delta)
		if _hunger_prey != null and is_instance_valid(_hunger_prey):
			target = _hunger_prey.global_position
			speed = _hunt_speed

	global_position = global_position.move_toward(target, speed * delta)


# --- Simulated hunger: preying on the lanes between passes at the player ------

## Cool the feed timer; keep stalking the current hauler (swallow it on contact,
## drop it if it slips too far); else, when hungry, pick the nearest exposed one.
func _tick_hunger(delta: float) -> void:
	_hunger_cd = maxf(0.0, _hunger_cd - delta)
	if _hunger_prey != null and (not is_instance_valid(_hunger_prey) or _hunger_prey.dead):
		_hunger_prey = null
	if _hunger_prey != null:
		var d := global_position.distance_to(_hunger_prey.global_position)
		if d < HUNGER_DEVOUR_RANGE:
			_devour_ai(_hunger_prey)
			_hunger_prey = null
			_hunger_cd = randf_range(HUNGER_MIN, HUNGER_MAX)   # sated, for a while
		elif d > BREAK_CHASE_RANGE * 1.6:
			_hunger_prey = null   # it slipped the gaze — back to the orbit
		return
	if _hunger_cd <= 0.0:
		_hunger_prey = _find_lane_prey()
		if _hunger_prey != null:
			_set_fury(true)   # eyes forward — it has a scent


## Nearest exposed ship on the lanes — HAULERS, PIRATES, and GUARDIAN patrols
## all. The beast is an apex; the whole lane fears it. Never the player (that's
## the hunt, not the hunger), and never a ship under the station's guns (the
## sanctuary spares the guard wing — only what's caught in the open is taken).
func _find_lane_prey() -> BuildShip:
	var best: BuildShip = null
	var best_d := HUNGER_RANGE * HUNGER_RANGE
	var seen := {}
	for grp in ["traders", "hostile_team", "player_team"]:
		for node in get_tree().get_nodes_in_group(grp):
			var bs := node as BuildShip
			if bs == null or seen.has(bs) or bs.dead:
				continue
			seen[bs] = true
			if bs.is_in_group("player_ship"):
				continue
			if bs.get("docked_at") != null:
				continue
			if bs.global_position.distance_to(AIShip.station_pos) < STATION_SAFE_RADIUS:
				continue
			var d := global_position.distance_squared_to(bs.global_position)
			if d < best_d:
				best_d = d
				best = bs
	return best


## Swallow a hauler whole and traceless (no wreck, no cargo — Voss's "no debris").
func _devour_ai(victim: BuildShip) -> void:
	_broadcast_distress(victim)
	Sfx.play_at("explosion", victim.global_position, -13.0, 0.5)   # a distant, muffled crunch
	victim.devour()
	_set_fury(false)   # sated


## If the player is near enough, they catch the doomed transmission: a distress
## fragment cut off mid-word into static. Too far, and the ship is simply gone —
## an empty patch where a hauler was.
func _broadcast_distress(victim: BuildShip) -> void:
	var player := get_tree().get_first_node_in_group("player_ship") as TestShip
	if player == null or player.dead:
		return
	if player.global_position.distance_to(victim.global_position) > DISTRESS_RANGE:
		return
	var frag: String = DISTRESS_LINES[randi() % DISTRESS_LINES.size()]
	var vname := "a hauler"
	if victim.build != null and victim.build.hull != null:
		vname = victim.build.hull.display_name
	if player.has_method("_flash_note"):
		player._flash_note("⚠ DISTRESS — %s: \"%s—\"   ✂ STATIC" % [vname, frag])
	Sfx.play("static", -5.0)


## A single heavy bite — a chunk, not a chip. The beast lunges its whole
## mass forward as it lands the hit; the sound is a wet, low crunch.
func _bite(player: TestShip) -> void:
	_bite_cd = BITE_INTERVAL
	player.take_damage(BITE_DAMAGE * lethality)
	Sfx.play_at("explosion", global_position, -7.0, 0.55)   # heavy crunch
	Sfx.play_at("scrape", global_position, -6.0, 0.5)       # tearing
	var tw := create_tween()
	tw.tween_property(_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE) * 1.18, 0.07)
	tw.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.16)


## The maw closes. A brief wind-up — jaws widening, a wrong inhale — then a
## lethal swallow, but only on prey the breath has already snared, which is
## what makes it dreadful rather than unfair.
func _tick_devour(player: TestShip, delta: float) -> void:
	if _devour_t <= 0.0:
		_begin_maw()
	_devour_t += delta
	if _devour_t >= DEVOUR_WINDUP:
		_devour(player)


func _begin_maw() -> void:
	_devour_t = 0.001
	Sfx.play("dread", -1.0, 0.7)                          # a low, wrong inhale
	Sfx.play_at("scrape", global_position, -3.0, 0.4)
	create_tween().tween_property(self, "modulate",
		Color(1.9, 0.7, 2.1), DEVOUR_WINDUP)
	create_tween().tween_property(_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE) * 1.45, DEVOUR_WINDUP)   # jaws widen


## Prey slipped the closing jaws (the snare lapsed, or it drifted clear).
func _release_maw() -> void:
	_devour_t = 0.0
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
	create_tween().tween_property(_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.2)


## The jaws shut: a one-shot, enough to end any hull outright through shield,
## armor and all — the loudest, most final womp in the beast's register.
func _devour(player: TestShip) -> void:
	_devour_t = 0.0
	Sfx.play("dread", 0.0, 0.85)                          # the swallow
	Sfx.play_at("explosion", global_position, -1.0, 0.35)
	create_tween().tween_property(_sprite, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.12)
	player.take_damage(1_000_000.0)


## The leap: a low incoming groan, a violet flare, then it crosses the gap
## faster than any ship can — landing in tendril-and-teeth range.
func _start_pounce() -> void:
	_pounce_cd = POUNCE_CD
	_pounce_t = POUNCE_DUR
	Sfx.play("dread", -1.0, 0.72)                           # the leap's roar
	Sfx.play_at("scrape", global_position, -5.0, 0.45)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 0.75, 1.8), 0.12)
	tw.tween_property(self, "modulate", Color.WHITE, 0.4)


## Inhale (violet swell, a hiss) — then three gouts of clinging shadow in a
## cone across the prey's escape line. The telegraph is the counterplay:
## when the beast glows, turn HARD.
func _exhale(player: TestShip) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.35, 0.85, 1.65), 0.45)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	Sfx.play_at("dread", global_position, -12.0, 1.7)
	await get_tree().create_timer(0.5).timeout
	if dead or not is_instance_valid(player) or player.dead:
		return
	var lead := player.global_position + player.velocity * 0.6
	var dir := (lead - global_position).normalized()
	for spread in [-0.3, 0.0, 0.3]:
		BreathCloud.spawn(get_parent(), global_position + dir * 100.0, dir.rotated(spread))
	Sfx.play_at("scrape", global_position, -8.0, 0.55)


# --- Leviathan mortality hooks (see the base class) ---

func _on_hit() -> void:
	modulate = Color(1.7, 1.4, 1.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


## Only reachable when `mortal` (the campaign finale): the Cinderweb is
## finally, truly ended.
func _perish() -> void:
	dead = true
	Sfx.play_at("explosion", global_position, 0.0, 0.45)
	_spill_hoard()
	queue_free()


## Driven to 0 HP anywhere else: it disgorges the hoard and folds into the
## dark. An ambusher just leaves; the ambient orbiter RETURNS on a later lap.
func _retreat_wounded() -> void:
	if _retreating:
		return
	_spill_hoard()
	if ambush:
		retreat()
	else:
		_reenter_orbit()


func _spill_hoard() -> void:
	for path in HOARD:
		# The hoard rolls hot: everything in it is Experimental-or-better,
		# so vengeance pays in 2-3 affix treasures.
		LootPickup.spawn(get_parent(), global_position, Affixes.roll_for_drop(load(path)))
	for i in 4:
		LootPickup.spawn_commodity(get_parent(), global_position, "stolen_goods")


## Fold away, then return dormant to a fresh orbit point and reappear after a
## lull — "it comes round when it comes round." Never truly gone here.
func _reenter_orbit() -> void:
	_retreating = true
	hunting = false
	Sfx.play_at("dread", global_position, -6.0, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.3, 0.15, 0.45, 0.0), 1.4)
	tw.tween_callback(_come_back)


func _come_back() -> void:
	hp = HP_MAX
	_t = randf() * TAU
	global_position = _orbit_point(_t)
	visible = false
	await get_tree().create_timer(45.0).timeout
	if not is_instance_valid(self):
		return
	modulate = Color.WHITE
	visible = true
	_retreating = false

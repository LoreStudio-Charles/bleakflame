class_name WayGate
extends Node2D
## The ancient ring at the system's rim — dead metal older than the colony, the
## door the Cinderweb came through. Appears when the finale charts it (Krayt's last
## transmission). It starts CLOSED: the pilot must feed it the WAKING SEQUENCE at
## the GateConsole. Entering the code runs the OPENING choreography (user spec,
## 2026-07-23): a beat of nothing, then a shudder, debris shaken loose, fog, a
## claxon, the aperture dilating open, fog pouring out to hide it, then clearing to
## a traversable portal. Flying in ends the demo — the ship shrinks into the deep.
##
## ART SEAM (three states, user 2026-07-23): two PNG frame folders —
##   assets/world/waygate_opening/ — the closed->open TRANSITION. Frame 0 (opening
##                                   -01) is the closed gate, HELD until the code
##                                   goes in ("hold on 01"); plays ONCE on open.
##   assets/world/waygate_open/     — the OPEN gate LOOP (gate-open-##), which runs
##                                   forever once the gate is open.
## The fog fully obscures the ring at the peak of the transition, so the swap from
## the last opening frame to the open loop happens hidden. Falls back to static
## waygate.png, then pure procedural rings.

const R := 150.0
const LightningFx := preload("res://scenes/flight/lightning.gd")   # reusable branching bolt
const SHAKE_MAG := 5.0
const IDLE_SPIN := 0.12         # rad/s — the dormant ring turning slowly
const OPEN_SPIN := 0.30         # a steadier, faster turn once it's an active doorway
## Warden crystal DORMANT: the gate art is the AWAKENED ring (gold veins blazing);
## while closed we tint it cold and dim so it reads as powered-down. Opening
## brightens it back to white = the light-veins igniting.
const COLD := Color(0.42, 0.47, 0.60)

enum Phase { CLOSED, OPENING, OPEN }

var phase := Phase.CLOSED
var _t := 0.0
var _shaking := false           # a gentle shake while the aperture dilates
var _crackling := false         # lightning arcs discharge while the veins ignite
var _arc_t := 0.0               # countdown to the next arc
var _aperture := 0.0            # 0 closed -> 1 fully dilated (drives the portal glow)
var _ring: Line2D
var _throat: Polygon2D
var _portal: Polygon2D
var _smoke: CPUParticles2D      # billowing pixel-smoke puffs that bury the ring as it opens
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _art: Node2D                # the gate visual (whichever of _sprite / _anim exists)
var _base := Vector2.ZERO       # spawn position; shudder offsets from here


static func create(pos: Vector2) -> WayGate:
	var g := WayGate.new()
	g.position = pos
	return g


func _ready() -> void:
	add_to_group("waygate")
	_base = position
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_throat = Polygon2D.new()
	_throat.polygon = _disc(R * 0.82, 40)
	_throat.color = Color(0.18, 0.34, 0.6, 0.4)
	_throat.material = add
	add_child(_throat)
	# The active portal core — invisible until the aperture dilates.
	_portal = Polygon2D.new()
	_portal.polygon = _disc(R * 0.6, 40)
	_portal.color = Color(0.7, 0.9, 1.0, 0.0)
	_portal.material = add
	_portal.scale = Vector2.ZERO
	add_child(_portal)
	_ring = Line2D.new()
	_ring.points = _disc(R, 48)
	_ring.closed = true
	_ring.width = 5.0
	_ring.default_color = Color(0.5, 0.75, 1.0, 0.9)
	_ring.material = add
	add_child(_ring)
	var inner := Line2D.new()
	inner.points = _disc(R * 0.6, 36)
	inner.closed = true
	inner.width = 2.5
	inner.default_color = Color(0.4, 0.6, 0.95, 0.7)
	inner.material = add
	inner.name = "inner"
	add_child(inner)

	_setup_art()


## DROP-IN GATE ART. Two frame folders, both optional:
##   assets/world/waygate_idle/     — the dormant ring's living idle loop (loops).
##   assets/world/waygate_opening/  — the closed→open transition (plays once). Its
##                                    FRAME 0 is the closed gate, HELD until it's
##                                    time to open (user's "hold on 01").
## If neither exists, falls back to the single static waygate.png, then to pure
## procedural rings. When art IS present it becomes the ring and the procedural
## rings retire — the fog/debris/shudder/portal-glow still play over the top.
func _setup_art() -> void:
	var sf := _build_frames()
	if sf != null:
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = sf
		_anim.z_index = -1
		var names := sf.get_animation_names()
		var w := 256.0
		if names.size() > 0 and sf.get_frame_count(names[0]) > 0:
			var t0 := sf.get_frame_texture(names[0], 0)
			if t0 != null:
				w = float(t0.get_width())
		_anim.scale = Vector2.ONE * (R * 2.3 / maxf(w, 1.0))
		add_child(_anim)
		if sf.has_animation("closed"):
			_anim.play("closed")          # the authored dormant ring
		elif sf.has_animation("opening"):
			_anim.animation = "opening"
			_anim.frame = 0
			_anim.pause()                 # HOLD ON 01 — the transition's closed frame
		elif sf.has_animation("open"):
			_anim.play("open")            # (fallback) straight to the open loop
		# The art is the ring now — retire the procedural rings AND the portal glow;
		# the authored frames carry all the light-veins.
		_art = _anim
		_ring.visible = false
		$inner.visible = false
		_throat.visible = false
		_portal.visible = false
		return
	var art_path := "res://assets/world/waygate.png"
	if ResourceLoader.exists(art_path):
		var tex: Texture2D = load(art_path)
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.z_index = -1
		_sprite.scale = Vector2.ONE * (R * 2.3 / maxf(float(tex.get_width()), 1.0))
		_sprite.modulate = COLD              # dormant: crystal powered down, veins cold
		add_child(_sprite)
		_art = _sprite
		_ring.visible = false
		$inner.visible = false
		_throat.visible = false
		_portal.color = Color(1.0, 0.86, 0.55, 0.0)   # warm gold shimmer, matching the veins
		_portal.scale = Vector2.ONE * 0.30


func is_open() -> bool:
	return phase == Phase.OPEN


## Called by flight_test once the pilot enters the waking sequence at the console.
func begin_opening() -> void:
	if phase != Phase.CLOSED:
		return
	phase = Phase.OPENING
	_run_opening()


## The choreography, beat for beat (user spec): hold on 01 -> it wakes with a shake
## and the first fog -> the aperture dilates (01->08) while MORE fog pours out until
## the ring is completely obscured -> under that cover the OPEN LOOP takes over ->
## the fog clears to the open gate, looping forever.
func _run_opening() -> void:
	# Hold on 01 — a breath after the code goes in.
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	# It wakes: a claxon, a gentle shake, debris shaken loose, the first fog.
	Sfx.play("claxon", -3.0)
	Sfx.play("dread", -10.0, 1.4)
	_shaking = true
	_spawn_debris()
	_smoke = _make_smoke()
	_smoke.emitting = true
	# The aperture dilates (01->08); more and more smoke pours out as it opens, layering
	# up until the ring is buried under it.
	Sfx.play("explosion", -12.0, 0.5)
	Sfx.play("shield_hit", -6.0, 0.5)   # the first crack of discharge
	_crackling = true                    # lightning storms off the ring as it ignites
	_open_aperture()
	await get_tree().create_timer(3.6).timeout
	if not is_inside_tree():
		return
	# Fully open and fully hidden: the discharge dies, swap to the OPEN state under
	# cover of the fog, and let the ring settle (stop shaking).
	_crackling = false
	_shaking = false
	_show_open_loop()
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	# The smoke clears — the open gate, looping forever. A doorway now.
	if _smoke != null and is_instance_valid(_smoke):
		_smoke.emitting = false   # stop pouring; the puffs already out fade on their own
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	phase = Phase.OPEN


func _open_aperture() -> void:
	# Frame-based transition if authored; else the STATIC Warden gate IGNITES — its
	# cold dormant crystal brightens to full blaze (the gold light-veins waking).
	if _anim != null and _anim.sprite_frames.has_animation("opening"):
		_anim.play("opening")
	elif _sprite != null:
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 3.0) \
			.set_trans(Tween.TRANS_SINE)
	# _aperture drives the spin wind-up (both paths); the portal bloom is only for
	# the STATIC gate — authored frames carry their own glowing core.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_aperture", 1.0, 3.0).set_trans(Tween.TRANS_CUBIC)
	if _portal.visible:
		tw.tween_property(_portal, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_portal, "color:a", 0.4, 3.0)


## After the transition, the gate loops its open state forever.
func _show_open_loop() -> void:
	if _anim != null and _anim.sprite_frames.has_animation("open"):
		_anim.play("open")


## Billowing pixel-smoke pouring out of the aperture — the whole fog effect now (the old
## flat obscuring disc is gone). Each puff is FAINT; density comes from many overlapping,
## so it reads as layered smoke that thickens over the ring, not a solid blob. Drop-in art:
## assets/fx/gate-smoke-1.png (add gate-smoke-2..N.png to vary). Puffs are born across the
## ring, drift gently outward with NO gravity, grow, spin, and fade in then out.
func _make_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var tex := "res://assets/fx/gate-smoke-1.png"
	if ResourceLoader.exists(tex):
		p.texture = load(tex)
	p.emitting = false
	p.amount = 90                 # many faint puffs LAYER into density
	p.lifetime = 3.2
	p.preprocess = 1.0            # start already billowing, not from an empty ring
	p.randomness = 0.8
	p.gravity = Vector2.ZERO      # smoke doesn't fall — it hangs and drifts
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = R * 0.75   # born ACROSS the ring so the center stays covered
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 26.0
	p.radial_accel_min = 10.0     # a gentle outward roll, not a fast blast
	p.radial_accel_max = 34.0
	p.damping_min = 6.0
	p.damping_max = 16.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -22.0
	p.angular_velocity_max = 22.0
	p.scale_amount_min = 1.8
	p.scale_amount_max = 4.0      # big soft puffs overlap heavily -> coverage
	var grow := Curve.new()       # small at birth, swelling as it rolls out
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()    # cold tint, VERY faint per puff, fading in then out
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.66, 0.74, 0.90, 0.0), Color(0.72, 0.79, 0.94, 0.18),
		Color(0.60, 0.68, 0.85, 0.14), Color(0.54, 0.62, 0.82, 0.0)])
	p.color_ramp = ramp
	p.z_index = 3                 # above the ring art
	add_child(p)
	return p


func _spawn_debris() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 26
	p.lifetime = 1.4
	p.explosiveness = 0.85
	p.spread = 180.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = R * 0.9
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.color = Color(0.35, 0.33, 0.3, 0.9)
	add_child(p)
	p.finished.connect(p.queue_free)


## One jagged, short-lived energy arc flung off the ring — gold-white Warden
## discharge. Several a second while _crackling reads as a storm of lightning.
func _spawn_arc() -> void:
	# A branching Warden discharge flung off the ring, drawn by the reusable Lightning fx
	# with a pixel-art arc strip tiled along it (cycles assets/fx/lightning-arc-#.png).
	var ang := randf() * TAU
	var start := Vector2.RIGHT.rotated(ang) * (R * 0.9)
	var end := Vector2.RIGHT.rotated(ang + randf_range(-0.45, 0.45)) * (R + R * randf_range(0.6, 1.7))
	var bolt := LightningFx.flash(self, start, end, {
		"color": Color(1.0, 0.92, 0.62),      # gold-white Warden discharge
		"texture": LightningFx.random_arc(),  # a pixel-art strip; falls back to a glow line
		"core_width": 18.0,                   # ~ the strip's native 16px height
		"glow_width": 34.0,                   # wide dim additive halo = the bloom
		"glow_alpha": 0.42,
		"generations": 4,                     # gentle large-scale wander; the strip adds crackle
		"chaos": 0.16,
		"branch_chance": 0.5,
		"life": randf_range(0.24, 0.46),      # linger so consecutive strikes OVERLAP into a glow
	})
	bolt.z_index = 4        # ABOVE the smoke (z 3) so the discharge flashes through the fog


func _process(delta: float) -> void:
	_t += delta
	_ring.rotation = _t * (0.15 + _aperture * 0.9)         # spins up as it wakes
	$inner.rotation = -_t * (0.28 + _aperture * 1.1)
	_throat.scale = Vector2.ONE * (0.94 + 0.06 * sin(_t * 1.3) + _aperture * 0.15)
	_throat.color.a = (0.3 + 0.15 * sin(_t * 0.9)) * (1.0 + _aperture)
	# Ancient machinery, still turning: a slow idle spin that winds UP as the
	# aperture dilates, then settles to a steady turn once it's an active doorway.
	if _art != null:
		var spin := IDLE_SPIN
		if phase == Phase.OPENING:
			spin += _aperture * 0.9
		elif phase == Phase.OPEN:
			spin = OPEN_SPIN
		_art.rotation += delta * spin
		if phase == Phase.CLOSED and _portal.visible:
			_portal.color.a = 0.05 + 0.04 * sin(_t * 1.4)   # a faint dormant core (static gate only)
	# A gentle shake while the aperture dilates; settle exactly on base otherwise.
	position = (_base + Vector2(randf_range(-SHAKE_MAG, SHAKE_MAG),
		randf_range(-SHAKE_MAG, SHAKE_MAG))) if _shaking else _base
	# Lightning: while igniting, fling an energy arc off the ring every so often.
	if _crackling:
		_arc_t -= delta
		if _arc_t <= 0.0:
			_spawn_arc()
			_arc_t = randf_range(0.05, 0.15)


## Build one SpriteFrames from whichever frame folders exist: "open" (the open loop)
## and "opening" (the closed->open transition, one-shot). Null if neither has frames.
func _build_frames() -> SpriteFrames:
	var open := _dir_pngs("res://assets/world/waygate_open")
	var opening := _dir_pngs("res://assets/world/waygate_opening")
	var closed_path := "res://assets/world/waygate_closed.png"
	var has_closed := ResourceLoader.exists(closed_path)
	if open.is_empty() and opening.is_empty() and not has_closed:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	if has_closed:
		sf.add_animation("closed")
		sf.set_animation_loop("closed", true)
		sf.set_animation_speed("closed", 1.0)
		sf.add_frame("closed", load(closed_path))
	if not open.is_empty():
		sf.add_animation("open")
		sf.set_animation_loop("open", true)
		sf.set_animation_speed("open", 8.0)
		for f in open:
			sf.add_frame("open", load(f))
	if not opening.is_empty():
		sf.add_animation("opening")
		sf.set_animation_loop("opening", false)
		# ~2.3 fps so the 8-frame dilation spans the fog build (~3.4s), not a blink.
		sf.set_animation_speed("opening", 2.3)
		for f in opening:
			sf.add_frame("opening", load(f))
	return sf


## Sorted res:// paths of the PNG frames in a folder. Mirrors the asteroid loader:
## trims ".import" so it still resolves the frames in an EXPORTED build (where the
## directory lists .import files, not the source .png).
func _dir_pngs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var file_name := f.trim_suffix(".import")
		if file_name.ends_with(".png"):
			var path := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(path) and not out.has(path):
				out.append(path)
	out.sort()
	return out


func _disc(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
